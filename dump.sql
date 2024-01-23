DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
DROP ROLE IF EXISTS Player;
DROP ROLE IF EXISTS Manager;
DROP TABLE IF EXISTS Member;
DROP TABLE IF EXISTS Item;
DROP TABLE IF EXISTS InventoryItem;
DROP TABLE IF EXISTS MemberPurchase;
DROP TABLE IF EXISTS Team;
DROP TABLE IF EXISTS TeamMember;
DROP TABLE IF EXISTS TeamJoinRequest;
DROP TABLE IF EXISTS Tournament;
DROP TABLE IF EXISTS TournamentTeam;

CREATE ROLE Player;
CREATE ROLE Manager;

CREATE TABLE Member (
    Username TEXT PRIMARY KEY,
    Balance INTEGER
);

CREATE TABLE Item (
    Id SERIAL PRIMARY KEY,
    Price INTEGER,
    Name TEXT
);

CREATE TABLE InventoryItem (
    Username TEXT REFERENCES Member (Username),
    ItemId INTEGER REFERENCES Item(Id)
);

CREATE TABLE MemberPurchase (
    Id SERIAL PRIMARY KEY,
    Username TEXT REFERENCES Member (Username),
    ItemId INTEGER REFERENCES Item(Id),
    Approved BOOLEAN
);


CREATE TABLE Team (
    Name TEXT PRIMARY KEY,
    Leader TEXT REFERENCES Member (Username)
);

CREATE TABLE TeamMember (
    TeamName TEXT REFERENCES Team(Name),
    Username TEXT REFERENCES Member (Username)
);

CREATE TABLE TeamJoinRequest (
    Id SERIAL PRIMARY KEY,
    TeamName TEXT REFERENCES Team(Name),
    Username TEXT REFERENCES Member (Username),
    Approved BOOLEAN
);

CREATE TABLE Tournament (
    Name TEXT PRIMARY KEY
);

CREATE TABLE TournamentTeam (
    TournamentName TEXT REFERENCES Tournament(Name),
    TeamName TEXT REFERENCES Team(Name)
);

DROP FUNCTION IF EXISTS Inventory;
DROP PROCEDURE IF EXISTS TransferBalance;
DROP PROCEDURE IF EXISTS ApplyToBuy;
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
CREATE PROCEDURE TransferBalance(toUser TEXT, amount INTEGER, fromUser whoami DEFAULT CURRENT_USER) AS
$func$
DECLARE
    srcBalance INTEGER;
    dstBalance INTEGER;
BEGIN
    IF fromUser = toUser
    THEN
        RAISE NOTICE 'Cannot transfer more to yourself';
        RETURN;
    END IF;

    raise notice '% => %', fromUser, toUser;

    SELECT INTO srcBalance balance from Member WHERE username = fromUser;
    SELECT INTO dstBalance balance from Member WHERE username = toUser;

    srcBalance = srcBalance - amount;

    IF srcBalance < 0
    THEN
        RAISE NOTICE 'Cannot transfer more money than you have';
        RETURN;
    END IF;

    dstBalance = dstBalance + amount;

    UPDATE Member SET balance=srcBalance WHERE username = fromUser;
    UPDATE Member SET balance=dstBalance WHERE username = toUser;

    RAISE NOTICE 'New Balance: %', srcBalance;
END
$func$ LANGUAGE PLPGSQL SECURITY DEFINER;

-- Apply to buy an item from the store.
CREATE PROCEDURE ApplyToBuy(item INTEGER, fromUser whoami DEFAULT CURRENT_USER) AS
$func$
BEGIN
    INSERT INTO memberpurchase (username, itemid, approved)
        VALUES (fromUser, item, false);
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

DROP POLICY IF EXISTS user_row_policy ON Member;
DROP POLICY IF EXISTS inventory_row_policy ON inventoryitem;
DROP POLICY IF EXISTS purchase_row_policy ON memberpurchase;
DROP POLICY IF EXISTS teamrequest_row_policy ON teamjoinrequest;

DROP POLICY IF EXISTS manager_member_policy ON Member;

CREATE POLICY user_row_policy ON Member FOR ALL TO player USING (username=current_user);
CREATE POLICY inventory_row_policy ON inventoryitem FOR ALL TO player USING (username=current_user);
CREATE POLICY purchase_row_policy ON memberpurchase FOR ALL TO player USING (username=current_user);
CREATE POLICY teamrequest_row_policy ON teamjoinrequest FOR ALL TO player USING (
    EXISTS(
        SELECT 1 FROM team
                 WHERE leader = current_user AND team.name = teamname
    )
);

ALTER TABLE Member ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventoryitem ENABLE ROW LEVEL SECURITY;
ALTER TABLE memberpurchase ENABLE ROW LEVEL SECURITY;
ALTER TABLE teamjoinrequest ENABLE ROW LEVEL SECURITY;

GRANT USAGE ON SCHEMA public TO PUBLIC;

GRANT SELECT ON item to PUBLIC;

GRANT SELECT ON Member to player;
GRANT SELECT ON inventoryitem to player;
GRANT SELECT ON memberpurchase to player;
GRANT SELECT ON team to player;
GRANT SELECT ON teammember to player;
GRANT SELECT ON tournament to player;
GRANT SELECT ON tournamentteam to player;
GRANT SELECT ON teamjoinrequest to player;

GRANT SELECT, UPDATE ON member to manager;
GRANT SELECT, UPDATE ON memberpurchase to manager;
GRANT INSERT ON inventoryitem to manager;
GRANT SELECT ON team to manager;
GRANT SELECT ON teammember to manager;
GRANT SELECT ON tournament to manager;
GRANT SELECT ON tournamentteam to manager;
GRANT SELECT ON teamjoinrequest to manager;

DELETE FROM inventoryitem;

DELETE FROM item;

DELETE FROM Member;

INSERT INTO Item(name, price) VALUES ('Sword', 50);

INSERT INTO Item(name, price) VALUES ('Potion', 5);

INSERT INTO Item(name, price) VALUES ('Magic Tome', 10);

INSERT INTO Item(name, price) VALUES ('Spellbook', 40);

INSERT INTO Item(name, price) VALUES ('Wand', 20);

INSERT INTO Item(name, price) VALUES ('Armour', 25);

DROP USER IF EXISTS m1;

CREATE USER m1 BYPASSRLS;

GRANT manager to m1;

DROP USER IF EXISTS u1;

CREATE USER u1 INHERIT;

GRANT player to u1;

INSERT INTO Member VALUES ('u1', 10000);

INSERT INTO InventoryItem VALUES ('u1', 4);

INSERT INTO InventoryItem VALUES ('u1', 2);

INSERT INTO InventoryItem VALUES ('u1', 1);

DROP USER IF EXISTS u2;

CREATE USER u2 INHERIT;

GRANT player to u2;

INSERT INTO Member VALUES ('u2', 10000);

INSERT INTO InventoryItem VALUES ('u2', 2);

INSERT INTO InventoryItem VALUES ('u2', 3);

INSERT INTO InventoryItem VALUES ('u2', 2);

DROP USER IF EXISTS u3;

CREATE USER u3 INHERIT;

GRANT player to u3;

INSERT INTO Member VALUES ('u3', 10000);

INSERT INTO InventoryItem VALUES ('u3', 3);

INSERT INTO InventoryItem VALUES ('u3', 6);

INSERT INTO InventoryItem VALUES ('u3', 3);

