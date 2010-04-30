#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Query date and time

use Data::Dumper qw(Dumper);
use Getopt::Std qw(getopts);

use LS30::Commander qw();
use LS30::ResponseMessage qw();
use LS30Command qw();
use LS30Connection qw();

use vars qw($opt_h);

getopts('h:');

my $ls30c = LS30Connection->new($opt_h);

$ls30c->connect();

LS30Command::addCommands();

my $ls30cmdr = LS30::Commander->new($ls30c);

my $hr = { title => 'Date/Time' };

my $query = LS30Command::queryCommand($hr);

if (defined $query) {
	my $response = $ls30cmdr->sendCommand($query);

	if ($response) {
		printf("%-40s | %s\n", $query, $response);
		my $resp = LS30::ResponseMessage->new($response);
		if ($resp) {
			printf("Current date/time is %s\n", $resp->{value});
		}
	}
}

exit(0);
