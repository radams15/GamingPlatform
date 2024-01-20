DROP FUNCTION IF EXISTS Inventory;
DROP FUNCTION IF EXISTS TransferBalance;

DROP DOMAIN IF EXISTS whoami;
CREATE DOMAIN whoami AS NAME
CHECK ( VALUE = CURRENT_USER );

CREATE FUNCTION Inventory() RETURNS TABLE(name TEXT, price INTEGER) AS
$func$
    SELECT item.name, item.price FROM public.inventoryitem AS i JOIN item ON item.Id = i.ItemId;
$func$ LANGUAGE SQL;

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