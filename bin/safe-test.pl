#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Set or clear 'safe testing' mode (alarms do not make any noise)

use Getopt::Std qw(getopts);

use LS30Command qw();
use LS30Connection qw();
use LS30::Commander qw();
use LS30::ResponseMessage qw();

use vars qw($opt_h $opt_n $opt_y);

getopts('h:ny');

if (! $opt_n && ! $opt_y) {
	die "Must specify either option -n or -y";
}

if ($opt_n && $opt_y) {
	die "Must not specify both option -n and -y";
}

# Commands to send to enable safe testing, by quietening the
# alarm when it is triggered

my $cmds_y = [
	{ title => 'Inner Siren Time', value => 0 },
	{ title => 'Remote Siren Time', value => '0 seconds' },
	{ title => 'Inner Siren Enable', value => 0 },
];

# Commands to re-establish secure alarm operations.

my $cmds_n = [
	{ title => 'Inner Siren Time', value => 180 },
	{ title => 'Remote Siren Time', value => '3 minutes' },
	{ title => 'Inner Siren Enable', value => 1 },
];

my $cmds = ($opt_y) ? $cmds_y : $cmds_n;

# Connect and send commands

my $ls30c = LS30Connection->new($opt_h);

$ls30c->Connect();

LS30Command::addCommands();

my $ls30cmdr = LS30::Commander->new($ls30c, 5);
my @output;

foreach my $hr (@$cmds) {
	my $cmd_spec = LS30Command::getCommand($hr->{title});

	my $cmd = LS30Command::setCommand($hr);
	my $response = $ls30cmdr->sendCommand($cmd);

	if ($response) {
		push(@output, [ $hr->{title}, $cmd, $response ] );
	}
}

foreach my $lr (@output) {
	my ($title, $cmd, $response) = @$lr;

	printf "%-40s | %-15s | %s\n", $title, $cmd, $response;
	my $resp_obj = LS30::ResponseMessage->new($response);
	print Data::Dumper::Dumper($resp_obj) if ($resp_obj);
}

exit(0);
