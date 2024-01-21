#!/usr/bin/perl

use warnings;
use strict;
use 5.030_000;

use DBI;

my $dbname = 'postgres';
my $host = 'localhost';
my @creds = ('postgres', 'password');

my $dbh = DBI->connect("dbi:Pg:dbname=$dbname;host=$host", @creds, {AutoCommit => 0, RaiseError => 1})
    or die "Unable to connect!";

my @files = ('create.sql', 'functions.sql', 'policy.sql');

my @users = map {"u$_"} (1..3);

my @items = (
    ["Sword", 50],
    ["Potion", 5],
    ["Magic Tome", 10],
    ["Spellbook", 40],
    ["Wand", 20],
    ["Armour", 25]
);


for (@files) {
    open FH, '<', $_;
    my $sql = join '', <FH>;
    close FH;

    $dbh->do($sql);
}

$dbh->do('DELETE FROM inventoryitem');
$dbh->do("DELETE FROM item");
$dbh->do('DELETE FROM Member');

for(@items) {
    $dbh->do("INSERT INTO Item(name, price) VALUES (?, ?);", {}, @$_);

    push @$_, $dbh->last_insert_id(undef, "public", "item");
}

for(@users) {
    $dbh->do("DROP USER IF EXISTS $_");
    $dbh->do("CREATE USER $_");
    $dbh->do("GRANT player to $_");

    $dbh->do('INSERT INTO Member VALUES (?, ?)', {}, $_, 10000);

    for my $i (1..3) {
        my $item = $items[int rand@items];
        $dbh->do('INSERT INTO InventoryItem VALUES (?, ?)', {}, $_, $item->[2]);
    }

    for my $i (1..1) {
        my $item = $items[int rand@items];
        $dbh->do('INSERT INTO MemberPurchase (username, itemid, approved) VALUES (?, ?, false)', {}, $_, $item->[2]);
    }
}



$dbh->commit;
$dbh->disconnect;