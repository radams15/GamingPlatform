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

my @users = map {"u$_"} (1..3);

my @items = (
    ["Sword", 50],
    ["Potion", 5],
    ["Magic Tome", 10],
    ["Spellbook", 40],
    ["Wand", 20],
    ["Armour", 25]
);

$dbh->do('DELETE FROM inventoryitem');
$dbh->do("DELETE FROM item");
$dbh->do('DELETE FROM "user"');

for(@items) {
    $dbh->do("INSERT INTO Item(name, price) VALUES (?, ?);", {}, @$_);

    push @$_, $dbh->last_insert_id(undef, "public", "item");
}

for(@users) {
    $dbh->do("DROP USER IF EXISTS $_");
    $dbh->do("CREATE USER $_");
    $dbh->do("GRANT player to $_");

    $dbh->do('INSERT INTO "user" VALUES (?, ?)', {}, $_, 10000);

    for my $i (1..2) {
        my $item = $items[int rand@items];
        $dbh->do('INSERT INTO InventoryItem VALUES (?, ?)', {}, $_, $item->[2]);
    }
}

for(@{$dbh->selectall_arrayref('SELECT * FROM "user";')}) {
    printf "%s has £%s\n", $_->[0], $_->[1]/100;
}

$dbh->commit;
$dbh->disconnect;