#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Read new events from the event log. Save them in a YAML file.
#   Optionally, display the new events.
#
#   Options:
#   -f event-log.yaml   Filename of YAML log file
#                       Default: etc/event-log.yaml
#   -h host:port        Connect to server at this host:port
#   -l n                Read at most 'n' events
#   -v                  Print new events as they are read.

use Data::Dumper qw(Dumper);
use Getopt::Std qw(getopts);
use YAML qw();

use LS30::Commander qw();
use LS30::EventMessage qw();
use LS30Command qw();
use LS30Connection qw();

use vars qw($opt_f $opt_h $opt_l $opt_v);

getopts('f:h:l:v');

my $yaml_file = $opt_f || 'etc/event-log.yaml';

my $ls30c = LS30Connection->new($opt_h);

$ls30c->connect();

LS30Command::addCommands();

my $ls30cmdr = LS30::Commander->new($ls30c);

my $event_data = {};

if (-e $yaml_file) {
	$event_data = YAML::LoadFile($yaml_file);
} else {

	# Initialise the file
	$event_data->{last_event_id} = 0;
}

my $highest_event = highestEvent($ls30cmdr);

if ($event_data->{last_event_id} == $highest_event) {
	print STDERR "No new events.\n";
	exit(0);
}

# Event numbers go from 1 .. 512
my $event_n = nextEvent($event_data->{last_event_id});
my $count   = 0;

while (1) {

	my $cmd_hr = {
		title => 'Event',
		value => $event_n,
	};

	my $cmd      = LS30Command::queryCommand($cmd_hr);
	my $response = $ls30cmdr->sendCommand($cmd);
	my $obj      = LS30::EventMessage->new($response);

	if (!$obj) {
		last;
	}

	if ($opt_v) {
		displayEvent($event_n, $obj);
	}

	push(@{ $event_data->{events} }, $obj);

	$count++;

	if ($opt_l && $count >= $opt_l) {

		# Limit reached, stop here
		last;
	}

	last if ($event_n == $highest_event);

	$event_n = nextEvent($event_n);
}

$event_data->{last_event_id} = $event_n;

if (!YAML::DumpFile($yaml_file, $event_data)) {
	die "Unable to save YAML data to $yaml_file";
}

exit(0);

# ---------------------------------------------------------------------------
# Find the highest event number (this is called event 01 on the display)
# ---------------------------------------------------------------------------

sub highestEvent {
	my ($ls30cmdr) = @_;

	my $cmd_hr = {
		title => 'Event',
		value => 1,
	};

	my $cmd      = LS30Command::queryCommand($cmd_hr);
	my $response = $ls30cmdr->sendCommand($cmd);
	my $obj      = LS30::EventMessage->new($response);

	if (!$obj) {
		die "Couldn't find highest event number";
	}

	return $obj->getHighestEvent();
}

# ---------------------------------------------------------------------------
# Increment an event number. Event numbers go from 1 .. 512.
# ---------------------------------------------------------------------------

sub nextEvent {
	my ($event_number) = @_;

	$event_number++;
	if ($event_number > 512) {
		$event_number = 1;
	}

	return $event_number;
}

# ---------------------------------------------------------------------------
# Display an event object
# ---------------------------------------------------------------------------

sub displayEvent {
	my ($id, $obj) = @_;

	printf("%s %s\n",
		$obj->{string},
		$obj->{display_string},
	);
}
