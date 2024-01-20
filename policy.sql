DROP POLICY IF EXISTS user_row_policy ON "user";
DROP POLICY IF EXISTS inventory_row_policy ON inventoryitem;
DROP POLICY IF EXISTS purchase_row_policy ON userpurchase;
DROP POLICY IF EXISTS teamrequest_row_policy ON teamjoinrequest;

CREATE POLICY user_row_policy ON "user" FOR ALL TO player USING (username=current_user);
CREATE POLICY inventory_row_policy ON inventoryitem FOR ALL TO player USING (username=current_user);
CREATE POLICY purchase_row_policy ON userpurchase FOR ALL TO player USING (username=current_user);
CREATE POLICY teamrequest_row_policy ON teamjoinrequest FOR ALL TO player USING (
    EXISTS(
        SELECT 1 FROM team
                 WHERE leader = current_user AND team.name = teamname
    )
);

ALTER TABLE "user" ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventoryitem ENABLE ROW LEVEL SECURITY;
ALTER TABLE userpurchase ENABLE ROW LEVEL SECURITY;
ALTER TABLE teamjoinrequest ENABLE ROW LEVEL SECURITY;

GRANT USAGE ON SCHEMA public TO player;

GRANT SELECT ON item to PUBLIC;

GRANT SELECT ON "user" to player;
GRANT SELECT ON inventoryitem to player;
GRANT SELECT ON userpurchase to player;
GRANT SELECT ON team to player;
GRANT SELECT ON teammember to player;
GRANT SELECT ON tournament to player;
GRANT SELECT ON tournamentteam to player;
GRANT SELECT ON teamjoinrequest to player;