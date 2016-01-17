#!/usr/bin/env perl
#   Copyright (C) 2010-2016, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Enrol a new device
#   Note: The device is enrolled, but the LS-30 does not send a response.
#   I'm not sure how long the learn command persists.
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

LS30Command::addCommands();

my $ls30cmdr = LS30::Commander->new($ls30c);

my $cmd_hr = { title => $command_title, };


my $cmd = LS30Command::queryCommand($cmd_hr);

if (!$cmd) {
	die "Invalid command: $cmd_hr->{title}";
}

print "Sending: $cmd\n";

my $cv = $ls30cmdr->queueCommand($cmd, 5);
my $response = $cv->recv();

if (!$response) {
	print "No response after 5 seconds.\n";
	exit(8);
}

print "Response was:\n";
print Dumper($response);

exit(0);
