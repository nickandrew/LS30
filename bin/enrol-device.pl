#!/usr/bin/env perl
#   Copyright (C) 2010-2016, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Enrol a new device. Enrolment lasts a maximum of 60 seconds; if no
#   device is enrolled within that time, a 'no enrolments' response is
#   received. It may be possible to enrol more than 1 device each time.
#
#   Usage:  enrol-device.pl [-h host:port] -t type
#
#   Type:
#     burglar
#     fire
#     controller
#     medical
#     special

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Getopt::Std qw(getopts);

use LS30::Commander qw();
use LS30::EventMessage qw();
use LS30::Log qw();
use LS30Command qw();
use LS30Connection qw();

use vars qw($opt_h $opt_t);

$| = 1;
getopts('h:t:');

my $options = {
	'burglar'    => 'Learn Burglar Sensor',
	'fire'       => 'Learn Fire Sensor',
	'controller' => 'Learn Controller',
	'medical'    => 'Learn Medical Button',
	'special'    => 'Learn Special Sensor',
};

$opt_t || die "Need option -t type (burglar, fire, controller, medical, special)";

my $command_title = $options->{$opt_t};

if (!$command_title) {
	die "Incorrect option -t $opt_t - must be one of (burglar, fire, controller, medical, special)";
}

my $ls30c = LS30Connection->new($opt_h);

$ls30c->connect();

my $exit_cv = AnyEvent->condvar;

# Handle the event whenever a device is added
$ls30c->onAddedDevice(sub {
	my $string = shift;

	if ($string =~ /^!i[bcefm]lno&$/) {
		LS30::Log::debug("No enrolment received for learn command");
		$exit_cv->send();
		return;
	}

	my $resp;
	eval {
		$resp = LS30Command::parseResponse($string);
	};

	if ($@) {
		LS30::Log::error("parseResponse($string) failed: $@");
		return;
	}

	if (!$resp || $resp->{error}) {
		my $err = (defined $resp) ? $resp->{error} : "Undefined response";
		LS30::Log::error("Error parsing added_device response: $err $string");
	} else {
		my $s = sprintf("%s index %d zone %s-%s",
			$resp->{title},
			$resp->{index},
			$resp->{zone},
			$resp->{id},
		);

		LS30::Log::timePrint($s);
		print $s, "\n";
		my $config = LS30Command::parseDeviceConfig($resp->{config});

		printf("Initial device configuration:\n");
		foreach my $k (sort (keys %$config)) {
			printf("%-40s | %s\n", $k, $config->{$k});
		}

		print "\n";
	}
});

LS30Command::addCommands();

my $ls30cmdr = LS30::Commander->new($ls30c);

my $cmd_hr = { title => $command_title, };

my $cmd = LS30Command::queryCommand($cmd_hr);

if (!$cmd) {
	die "Invalid command: $command_title";
}

LS30::Log::debug("Sending: $cmd");

my $cv = $ls30cmdr->queueCommand($cmd, 5);
my $response = $cv->recv();

if (!$response) {
	print "No response after 5 seconds.\n";
	exit(8);
}

# Enrolments are open for a maximum of 60 seconds. Wait a few seconds
# more, processing added_device events, or exit immediately when an
# added_device event meaning 'no enrolments' is received.
my $timer = AnyEvent->timer(
	after => 70,
	cb    => sub {
		$exit_cv->send();
	},
);

$exit_cv->recv();

exit(0);
