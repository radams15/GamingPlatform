DROP FUNCTION IF EXISTS Inventory;
DROP FUNCTION IF EXISTS TransferBalance;
DROP FUNCTION IF EXISTS ApplyToBuy;
DROP FUNCTION IF EXISTS ListPurchaseApplications;
DROP FUNCTION IF EXISTS ApprovePurchaseApplication;

-- Allows for SECURITY DEFINER functions to find the current user
-- https://stackoverflow.com/questions/31712286/recording-the-invoker-of-a-postgres-function-that-is-set-to-security-definer
DROP DOMAIN IF EXISTS whoami;
CREATE DOMAIN whoami AS NAME
CHECK ( VALUE = CURRENT_USER );

CREATE FUNCTION Inventory() RETURNS TABLE(name TEXT, price INTEGER) AS
$func$
    SELECT item.name, item.price
    FROM public.inventoryitem AS i
        JOIN item
            ON item.Id = i.ItemId;
$func$ LANGUAGE SQL;

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

    SELECT INTO srcBalance balance from "user" WHERE username = fromUser;
    SELECT INTO dstBalance balance from "user" WHERE username = toUser;

    srcBalance = srcBalance - amount;

    IF srcBalance < 0
    THEN
        RAISE NOTICE 'Cannot transfer more money than you have';
        RETURN 1;
    END IF;

    dstBalance = dstBalance + amount;

    UPDATE "user" SET balance=srcBalance WHERE username = fromUser;
    UPDATE "user" SET balance=dstBalance WHERE username = toUser;

    RAISE NOTICE 'Src: %, Dst: %', srcBalance, dstBalance;

    RETURN 0;
END
$func$ LANGUAGE PLPGSQL SECURITY DEFINER;

-- Apply to buy an item from the store.
CREATE FUNCTION ApplyToBuy(itemId INTEGER, fromUser whoami DEFAULT CURRENT_USER) RETURNS INTEGER AS
$func$
BEGIN
    INSERT INTO userpurchase
        VALUES (fromUser, itemid, false);

    RETURN 0;
END
$func$ LANGUAGE PLPGSQL SECURITY DEFINER;

-- List purchase applications. Can be called by only the user to show their applications, or by a manager to show
-- all applications.
CREATE FUNCTION ListPurchaseApplications() RETURNS TABLE(id INTEGER, username TEXT, itemName TEXT, itemPrice INTEGER, approved BOOLEAN) AS
$func$
BEGIN
    RETURN QUERY
        SELECT userpurchase.id, userpurchase.username, item.name, item.price, userpurchase.approved
        FROM userpurchase
            JOIN item
                ON userpurchase.itemid = item.id
        WHERE userpurchase.approved <> true;
END
$func$ LANGUAGE PLPGSQL SECURITY INVOKER;

-- Approve a purchase
CREATE FUNCTION ApprovePurchaseApplication(applicationId INTEGER) RETURNS INTEGER AS
$func$
DECLARE
    applicationUser TEXT;
    userBalance INTEGER;
    itemPrice INTEGER;
    itemId INTEGER;

    alreadyApproved BOOLEAN;
BEGIN
    SELECT INTO alreadyApproved, applicationUser, userBalance, itemPrice, itemId
        userpurchase.approved, "user".username, "user".balance, item.price, item.id
    FROM userpurchase
        JOIN "user"
            ON userpurchase.username = "user".username
        JOIN item
            ON userpurchase.itemid = item.id
    WHERE userpurchase.id = applicationId;

    IF alreadyApproved
    THEN
        RAISE NOTICE 'Application already approved';
        RETURN 1;
    END IF;

    userBalance = userBalance - itemPrice;

    IF userBalance < 0
    THEN
        RAISE NOTICE 'Insufficient funds for approval';
        RETURN 1;
    END IF;

    UPDATE "user" SET balance=userBalance
        WHERE "user".username = applicationUser;

    UPDATE userpurchase SET approved=true
        WHERE id = applicationId;

    INSERT INTO inventoryitem VALUES (applicationUser, itemId);

    RAISE NOTICE 'New balance: %, price %', userBalance, itemPrice;

    RETURN 0;
END
$func$ LANGUAGE PLPGSQL SECURITY INVOKER;