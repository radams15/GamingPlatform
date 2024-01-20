#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use 5.030_000;

use DBI;

my $dbname = 'postgres';
my $host = 'localhost';
my @creds = ('postgres', 'password');
my $dbh = DBI->connect("dbi:Pg:dbname=$dbname;host=$host", @creds, {AutoCommit => 0});

for(@{$dbh->selectall_arrayref('SELECT * FROM Table1;')}) {
    printf "%s, %s\n", $_->[0], $_->[1];
}

$dbh->disconnect;