#!/usr/bin/env perl
#   Copyright (C) 2010-2016, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Print a list of enrolled devices.
#
#   Options:
#     -h host:port       Override the server hostname and port
#     -v                 Verbose (additional info about each enrolled device)
#     -y                 Create/Modify etc/devices.yaml file

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Getopt::Std qw(getopts);
use YAML qw();

use LS30::Commander qw();
use LS30::Type qw();
use LS30Command qw();
use LS30Connection qw();

use vars qw($opt_h $opt_v $opt_y);

getopts('h:vy');

my $devices_file = "etc/devices.yaml";

my $ls30c = LS30Connection->new($opt_h);

$ls30c->connect();

LS30Command::addCommands();

my $ls30cmdr = LS30::Commander->new($ls30c);

my @responses;
my @device_code_list = LS30::Type::listStrings('Device Code');

my $devs     = {};
my $dev_seen = {};

if (-f $devices_file) {
	$devs = YAML::LoadFile($devices_file);
}

foreach my $device_name (@device_code_list) {

	my $cv1 = $ls30cmdr->getDeviceCount($device_name);
	my $count = $cv1->recv();

	if (!defined $count) {
		die "Error retrieving device count";
	}

	my $index = -1;

	for ($index = 0; $index < $count; ++$index) {

		printf("%s %03d\n", $device_name, $index);
		my $cv = $ls30cmdr->getDeviceStatus($device_name, $index);
		my $device = $cv->recv();

		next if (!$device);

		print Data::Dumper::Dumper($device);
		$device->commander($ls30cmdr);

		$device->setZoneId($device->{zone}, $device->{id} + 1);
	}
}

if ($opt_y) {

	# Print all missing devices
	foreach my $dev_id (sort (keys %$devs)) {
		if (!$dev_seen->{$dev_id}) {
			print STDERR "Warning: Device $dev_id in $devices_file not seen\n";
		}
	}

	YAML::DumpFile($devices_file, $devs);
}

exit(0);
