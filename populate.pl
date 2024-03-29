#!/usr/bin/perl

use warnings;
use strict;
use 5.030_000;

use DBI;

my $dbname = 'postgres';
my $host = 'localhost';
my @creds = ('postgres', 'password');

my $dbh = DBI->connect("dbi:Pg:dbname=$dbname;host=$host;sslmode=require", @creds, {AutoCommit => 0, RaiseError => 1})
    or die "Unable to connect!";

sub last_inserted {
    $dbh->last_insert_id(undef, "public", $_[0])
}

open DUMP, '>', 'dump.sql';

sub exec_sql {
    my ($sql, @args) = @_;

    my $formatted = $sql;
    for (@args) {
        my $arg = $_;
        unless(/^\d+$/) {
            $arg = "'$arg'";
        }

        $formatted =~ s/\?/$arg/;
    }

    $formatted = "$formatted;" unless($formatted =~ /;$/g); # Append semicolon if none there

    print DUMP "$formatted\n\n";

    my $stmt = $dbh->prepare($sql);

    $stmt->execute(@args);
}

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

    exec_sql($sql);
}

exec_sql('DELETE FROM inventoryitem');
exec_sql("DELETE FROM item");
exec_sql('DELETE FROM Member');

for(@items) {
    exec_sql("INSERT INTO Item(name, price) VALUES (?, ?)", @$_);

    push @$_, last_inserted "item";
}

exec_sql("DROP USER IF EXISTS m1");
exec_sql("CREATE USER m1 BYPASSRLS");
exec_sql("GRANT manager to m1");

for(@users) {
    exec_sql("DROP USER IF EXISTS $_");
    exec_sql("CREATE USER $_ INHERIT");
    exec_sql("GRANT player to $_");

    exec_sql('INSERT INTO Member VALUES (?, ?)', $_, 10000);

    for my $i (1..3) {
        my $item = $items[int rand@items];
        exec_sql('INSERT INTO InventoryItem VALUES (?, ?)', $_, $item->[2]);
    }

    #for my $i (1..1) {
    #    my $item = $items[int rand@items];
    #    exec_sql('INSERT INTO MemberPurchase (username, itemid, approved) VALUES (?, ?, false)', $_, $item->[2]);
    #}
}


# Create team, owned by u1, with u2 being a member and u3 requesting to join.
#exec_sql("INSERT INTO Team(name, leader) VALUES (?, ?)", "team1", "u1");
#exec_sql("INSERT INTO TeamMember(teamname, username) VALUES (?, ?)", "team1", "u1");
#exec_sql("INSERT INTO TeamMember(teamname, username) VALUES (?, ?)", "team1", "u2");
#exec_sql("INSERT INTO teamjoinrequest(teamname, username, approved) VALUES (?, ?, false)", "team1", "u3");


close DUMP;

$dbh->commit;
$dbh->disconnect;