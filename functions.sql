DROP FUNCTION IF EXISTS Inventory;
DROP FUNCTION IF EXISTS TransferBalance;
DROP FUNCTION IF EXISTS ApplyToBuy;
DROP FUNCTION IF EXISTS ListPurchaseApplications;
DROP PROCEDURE IF EXISTS ApprovePurchaseApplication;

DROP PROCEDURE IF EXISTS CreateTeam;
DROP PROCEDURE IF EXISTS RequestJoinTeam;
DROP FUNCTION IF EXISTS ListTeamRequests;
DROP PROCEDURE IF EXISTS AcceptTeamRequest;

-- Allows for SECURITY DEFINER functions to find the current user
-- https://stackoverflow.com/questions/31712286/recording-the-invoker-of-a-postgres-function-that-is-set-to-security-definer
DROP DOMAIN IF EXISTS whoami;
CREATE DOMAIN whoami AS NAME
CHECK ( VALUE = CURRENT_USER );



-- User Functions --



-- List all items in users inventory by name
CREATE FUNCTION Inventory() RETURNS TABLE(name TEXT, price INTEGER) AS
$func$
    SELECT item.name, item.price
    FROM public.inventoryitem AS i
        JOIN item
            ON item.Id = i.ItemId;
$func$ LANGUAGE SQL SECURITY INVOKER;

-- Transfer balance from your account to another user.
CREATE FUNCTION TransferBalance(toUser TEXT, amount INTEGER, fromUser whoami DEFAULT CURRENT_USER) RETURNS INTEGER AS
$func$
DECLARE
    srcBalance INTEGER;
    dstBalance INTEGER;
BEGIN
    IF fromUser = toUser
    THEN
        RAISE NOTICE 'Cannot transfer more to yourself';
        RETURN 1;
    END IF;

    SELECT INTO srcBalance balance from Member WHERE username = fromUser;
    SELECT INTO dstBalance balance from Member WHERE username = toUser;

    srcBalance = srcBalance - amount;

    IF srcBalance < 0
    THEN
        RAISE NOTICE 'Cannot transfer more money than you have';
        RETURN 1;
    END IF;

    dstBalance = dstBalance + amount;

    UPDATE Member SET balance=srcBalance WHERE username = fromUser;
    UPDATE Member SET balance=dstBalance WHERE username = toUser;

    RAISE NOTICE 'Src: %, Dst: %', srcBalance, dstBalance;

    RETURN 0;
END
$func$ LANGUAGE PLPGSQL SECURITY DEFINER;

-- Apply to buy an item from the store.
CREATE FUNCTION ApplyToBuy(itemId INTEGER, fromUser whoami DEFAULT CURRENT_USER) RETURNS INTEGER AS
$func$
BEGIN
    INSERT INTO memberpurchase
        VALUES (fromUser, itemId, false);

    RETURN 0;
END
$func$ LANGUAGE PLPGSQL SECURITY DEFINER;

-- List purchase applications. Can be called by only the user to show their applications, or by a manager to show
-- all applications.
CREATE FUNCTION ListPurchaseApplications() RETURNS
    TABLE(id INTEGER, username TEXT, itemName TEXT, itemPrice INTEGER, approved BOOLEAN)
AS
$func$
BEGIN
    RETURN QUERY
        SELECT memberpurchase.id, memberpurchase.username, item.name, item.price, memberpurchase.approved
        FROM memberpurchase
            JOIN item
                ON memberpurchase.itemid = item.id
        WHERE memberpurchase.approved <> true;
END
$func$ LANGUAGE PLPGSQL SECURITY INVOKER;

-- Approve a purchase
CREATE PROCEDURE ApprovePurchaseApplication(applicationId INTEGER) AS
$func$
DECLARE
    applicationUser TEXT;
    userBalance INTEGER;
    itemPrice INTEGER;
    itemId INTEGER;

    alreadyApproved BOOLEAN;
BEGIN
    SELECT INTO alreadyApproved, applicationUser, userBalance, itemPrice, itemId
        memberpurchase.approved, Member.username, Member.balance, item.price, item.id
    FROM memberpurchase
        JOIN Member
            ON memberpurchase.username = Member.username
        JOIN item
            ON memberpurchase.itemid = item.id
    WHERE memberpurchase.id = applicationId;

    IF alreadyApproved
    THEN
        RAISE NOTICE 'Application already approved';
        RETURN;
    END IF;

    userBalance = userBalance - itemPrice;

    IF userBalance < 0
    THEN
        RAISE NOTICE 'Insufficient funds for approval';
        RETURN;
    END IF;

    UPDATE Member SET balance=userBalance
        WHERE Member.username = applicationUser;

    UPDATE memberpurchase SET approved=true
        WHERE id = applicationId;

    INSERT INTO inventoryitem VALUES (applicationUser, itemId);

    RAISE NOTICE 'New balance: %, price %', userBalance, itemPrice;
END
$func$ LANGUAGE PLPGSQL SECURITY INVOKER;



-- Team Functions --



-- Create a team owned by you.
CREATE PROCEDURE CreateTeam(teamName TEXT, owner whoami DEFAULT CURRENT_USER) AS
$func$
BEGIN
    RAISE NOTICE 'Create team %. Leader %', teamName, owner;

    INSERT INTO Team VALUES (teamName, owner);
    INSERT INTO teammember VALUES (teamName, owner);
end;
$func$ LANGUAGE PLPGSQL SECURITY DEFINER;

-- Request to join a team
CREATE PROCEDURE RequestJoinTeam(teamToJoin TEXT, requestingUser whoami DEFAULT CURRENT_USER) AS
$func$
BEGIN
    IF COUNT((SELECT 1 FROM teamjoinrequest
                       WHERE username = requestingUser -- same user
                       AND   teamname = teamToJoin     -- same team
               )
       ) > 0
    THEN
        RAISE NOTICE 'Request already sent or already in team';
        RETURN;
    END IF;

    RAISE NOTICE 'Request to join team %.', teamToJoin;

    INSERT INTO teamjoinrequest (teamname, username, approved) VALUES (teamToJoin, requestingUser, false);
end;
$func$ LANGUAGE PLPGSQL SECURITY DEFINER;

-- List requests to teams you lead
CREATE FUNCTION ListTeamRequests() RETURNS TABLE(id INTEGER, teamName TEXT, requestingUser TEXT) AS
$func$
BEGIN
    RETURN QUERY
        SELECT teamjoinrequest.id, teamjoinrequest.teamname, username
        FROM teamjoinrequest
        WHERE approved <> true;
end;
$func$ LANGUAGE PLPGSQL SECURITY INVOKER;

-- Accept a team request, only works for teams you lead
CREATE PROCEDURE AcceptTeamRequest(requestId INTEGER, callingUser whoami DEFAULT CURRENT_USER) AS
$func$
DECLARE
    teamLeader TEXT;
    teamName TEXT;
    requestingUser TEXT;
BEGIN
    SELECT INTO teamLeader, teamName, requestingUser
        team.leader, team.name, t.username
        FROM team
            JOIN public.teamjoinrequest t on team.name = t.teamname
    WHERE t.id = requestId;

    IF callingUser <> teamLeader
    THEN
        RAISE NOTICE 'You do not own this team';
    END IF;

    UPDATE teamjoinrequest SET approved=true
    WHERE id = requestId;

    INSERT INTO teammember VALUES (teamname, requestingUser);
end;
$func$ LANGUAGE PLPGSQL SECURITY DEFINER;