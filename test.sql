-- Do following as 'u1'
SET ROLE u1;

-- Show initial balance
SELECT * FROM Member;

CALL TransferBalance('u2', 1234);

-- Show final balance
SELECT * FROM Member;

-- View u1 inventory
SELECT * FROM Inventory();

-- Show all purchasable items ordered by price
SELECT * FROM Item ORDER BY Price DESC;

-- Apply to buy sword for 50 credits
CALL ApplyToBuy(1);

-- View our pending purchase
SELECT * FROM ListPurchaseApplications();

-- Become manager
SET ROLE m1;

-- View all pending purchases
SELECT * FROM ListPurchaseApplications();

-- Approve purchase 1
CALL ApprovePurchaseApplication(1);

-- No longer a pending purchase
SELECT * FROM ListPurchaseApplications();

-- Become u1 again
SET ROLE u1;

-- View u1 inventory - we should have a new sword.
SELECT * FROM Inventory();

-- Create a team
CALL CreateTeam('team1');

-- u1 is now leader of team1
SELECT * FROM Team;

-- No pending join requests
SELECT * FROM ListTeamRequests();

-- Become u2
SET ROLE u2;

-- u2 new balance
SELECT * FROM Member;

-- Request to join team1
CALL RequestJoinTeam('team1');

-- Become u1 again
SET ROLE u1;

-- One pending join request
SELECT * FROM ListTeamRequests();

-- Accept join request 1
CALL AcceptTeamRequest(1);

-- No pending join requests
SELECT * FROM ListTeamRequests();

-- View membership of team1
SELECT * FROM TeamMember WHERE teamname='team1';