DELETE FROM "user";

DO $populate$
DECLARE
    users TEXT[] := ARRAY ['u1', 'u2', 'u3'];
    var TEXT;
BEGIN
    FOREACH var IN ARRAY users LOOP
        EXECUTE format($fmt$
            DROP USER IF EXISTS %I;
            CREATE USER %I;
            GRANT player to %I;
        $fmt$, var, var, var);

        INSERT INTO "user" VALUES (var, 0);
    END LOOP;
END;
$populate$
LANGUAGE plpgsql;