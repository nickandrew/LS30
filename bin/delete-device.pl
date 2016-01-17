#!/usr/bin/env perl
#   Copyright (C) 2010-2016, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Delete a device from the LS-30
#
#   Usage:  delete-device.pl [-h host:port] -t type -n number
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

use vars qw($opt_h $opt_n $opt_t);

$| = 1;
getopts('h:n:t:');

my $options = {
	'burglar'    => 'Delete Burglar Sensor',
	'fire'       => 'Delete Fire Sensor',
	'controller' => 'Delete Controller',
	'medical'    => 'Delete Medical Button',
	'special'    => 'Delete Special Sensor',
};

$opt_t || die "Need option -t type (burglar, fire, controller, medical, special)";

if (!defined $opt_n || $opt_n !~ /^\d+$/) {
	die "Need option -n number (0 through 9)";
}

my $command_title = $options->{$opt_t};

if (!$command_title) {
	die "Incorrect option -t $opt_t - must be one of (burglar, fire, controller, medical, special)";
}

my $ls30c = LS30Connection->new($opt_h);

$ls30c->connect();

LS30Command::addCommands();

my $ls30cmdr = LS30::Commander->new($ls30c);

my $cmd_spec = LS30Command::getDeleteCommandSpec($command_title);

if (!$cmd_spec) {
	die "Invalid command: $command_title";
}

my $cmd = LS30Command::formatDeleteCommand({
	title => $command_title,
	device_id => $opt_n,
});

print "Sending: $cmd\n";

my $cv = $ls30cmdr->queueCommand($cmd);
my $response = $cv->recv();

if (!$response) {
	print "No response.\n";
	exit(8);
}
elsif ($response eq $cmd) {
	print "$command_title number $opt_n OK\n";
}
else {
	print "Delete Response was: $response\n";
}

exit(0);
