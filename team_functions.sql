DROP PROCEDURE IF EXISTS CreateTeam;
DROP PROCEDURE IF EXISTS RequestJoinTeam;
DROP FUNCTION IF EXISTS ListTeamRequests;
DROP PROCEDURE IF EXISTS AcceptTeamRequest;

-- Create a team owned by you.
CREATE PROCEDURE CreateTeam(teamName TEXT, owner whoami DEFAULT CURRENT_USER) AS
$func$
BEGIN
    RAISE NOTICE 'Create team %. Leader %', teamName, owner;

    INSERT INTO Team VALUES (teamName, owner);
end;
$func$ LANGUAGE PLPGSQL SECURITY DEFINER;

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

CREATE FUNCTION ListTeamRequests() RETURNS TABLE(id INTEGER, teamName TEXT, requestingUser TEXT) AS
$func$
BEGIN
    RETURN QUERY
        SELECT teamjoinrequest.id, teamjoinrequest.teamname, username
        FROM teamjoinrequest
        WHERE approved <> true;
end;
$func$ LANGUAGE PLPGSQL SECURITY INVOKER;

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