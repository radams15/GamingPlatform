DROP POLICY IF EXISTS user_row_policy ON "user";

CREATE POLICY user_row_policy ON "user" FOR ALL TO player USING (username=current_user);
ALTER TABLE "user" ENABLE ROW LEVEL SECURITY;