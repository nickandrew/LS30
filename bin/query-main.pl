#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Show the values of the most important operational parameters


use Getopt::Std qw(getopts);

use LS30Command qw();
use LS30Connection qw();
use LS30::Commander qw();
use LS30::ResponseMessage qw();

my $queries = [
	{ title => 'Inner Siren Time', },
	{ title => 'Remote Siren Time', },
	{ title => 'Inner Siren Enable', },
	{ title => 'Exit Delay', },
	{ title => 'Entry Delay', },
	{ title => 'Entry delay beep', },
	{ title => 'Operation Mode', },
	{ title => 'Partial Arm', group_number => 'Group 91' },
	{ title => 'Partial Arm', group_number => 'Group 92' },
	{ title => 'Partial Arm', group_number => 'Group 93' },
	{ title => 'Partial Arm', group_number => 'Group 94' },
	{ title => 'Partial Arm', group_number => 'Group 95' },
	{ title => 'Partial Arm', group_number => 'Group 96' },
	{ title => 'Partial Arm', group_number => 'Group 97' },
	{ title => 'Partial Arm', group_number => 'Group 98' },
	{ title => 'Partial Arm', group_number => 'Group 99' },
];


my $ls30c = LS30Connection->new();

$ls30c->connect();

LS30Command::addCommands();

my $ls30cmdr = LS30::Commander->new($ls30c, 5);
my @output;

foreach my $hr (@$queries) {
	my $cmd_spec = LS30Command::getCommand($hr->{title});

	my $cmd      = LS30Command::queryCommand($hr);
	my $response = $ls30cmdr->sendCommand($cmd);

	if ($response) {
		push(@output, [$hr->{title}, $cmd, $response]);
	}
}

foreach my $lr (@output) {
	my ($title, $cmd, $response) = @$lr;

	if (!defined $response) {
		printf "%-40s | %-15s | %s\n", $title, $cmd, 'no response';
		return;
	}

	my $resp_obj = LS30::ResponseMessage->new($response);
	if (!$resp_obj) {
		printf "%-40s | %-15s | %s\n", $title, $cmd, $response;
	} else {
		my $v = $resp_obj->{value};
		if (!defined $v) {
			print Data::Dumper::Dumper($resp_obj);
			$v = 'undefined';
		}
		printf "%-40s | %-15s | %s\n", $title, $cmd, $v;
	}
}

