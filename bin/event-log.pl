#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Print event log

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Getopt::Std qw(getopts);

use LS30::Commander qw();
use LS30::EventMessage qw();
use LS30Command qw();
use LS30Connection qw();

use vars qw($opt_h);

getopts('h:');

my $ls30c = LS30Connection->new($opt_h);

$ls30c->connect();

LS30Command::addCommands();

my $ls30cmdr = LS30::Commander->new($ls30c);

my $data = {};
my $min  = shift @ARGV;
$min = 0 if (!defined $min);
my $max = shift @ARGV;
$max = 511 if (!defined $max);

my $cmd_spec = LS30Command::getCommand('Event');

foreach my $n ($min .. $max) {
	my $cmd_hr = {
		title => 'Event',
		value => $n,
	};

	my $cmd = LS30Command::queryCommand($cmd_hr);

	my $response = $ls30cmdr->sendCommand($cmd);
	my $obj      = LS30::EventMessage->new($response);

	next if (!$obj);
	printf("Event %3d\n", $n);
	print Dumper($obj);

	last if ($obj->{highest_event} && $n >= $obj->{highest_event});
}

exit(0);
