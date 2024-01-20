DROP FUNCTION IF EXISTS Inventory;

CREATE FUNCTION Inventory() RETURNS TABLE(name TEXT, price INTEGER) AS
$func$
    SELECT item.name, item.price FROM public.inventoryitem AS i JOIN item ON item.Id = i.ItemId;
$func$ LANGUAGE SQL;