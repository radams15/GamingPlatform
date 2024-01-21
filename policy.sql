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