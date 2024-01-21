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