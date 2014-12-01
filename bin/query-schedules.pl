#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Query all operation schedules: Day of Week (7 days plus Daily) x 20 settings.
#
#   Options:
#     -h host:port          Specify LS30 server host:port
#     -s filename           Save queries and responses to YAML file

use strict;

use Getopt::Std qw(getopts);
use YAML qw();

use LS30::Commander qw();
use LS30::ResponseMessage qw();
use LS30::Type qw();
use LS30Command qw();
use LS30Connection qw();

use vars qw($opt_h $opt_s);

getopts('h:s:');

my $ls30c = LS30Connection->new($opt_h);

$ls30c->connect();

LS30Command::addCommands();

my $ls30cmdr = LS30::Commander->new($ls30c);

my @data;

my $cmd_hr = {
	title => 'Query Operation Schedule',
};

my @days_of_week = LS30::Type::listStrings('Schedule Day of Week');

foreach my $day_of_week (@days_of_week) {

	$cmd_hr->{day_of_week} = $day_of_week;

	foreach my $id (0 .. 19) {
		$cmd_hr->{id} = $id;

		my $cmd = LS30Command::queryCommand($cmd_hr);

		my $response = $ls30cmdr->sendCommand($cmd);

		my $hr = {
			day      => $day_of_week,
			id       => $id,
			cmd      => $cmd,
			response => $response,
		};

		push(@data, $hr);
	}
}

foreach my $hr (@data) {
	my $response = $hr->{response};

	if ($response) {
		my $resp = LS30::ResponseMessage->new($response);

		my $response_string = '';

		if ($resp) {
			my $op_code = $resp->{op_code} || 'no change';

			$response_string = sprintf("%s %s Zone %s",
				$resp->{start_time} || '?????',
				$op_code,
				$resp->{zone} || '??' ,
			);
		}

		printf("%-6s | %2d | %s | %s | %s\n",
			$hr->{day},
			$hr->{id},
			$hr->{cmd},
			$response,
			$response_string,
		);
	}
}

if ($opt_s) {
	YAML::DumpFile($opt_s, \@data);
}

exit(0);
