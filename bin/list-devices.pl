#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Print a list of known devices.
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

my $s        = '';
my $s2       = '';
my $devs     = {};
my $dev_seen = {};

if (-f $devices_file) {
	$devs = YAML::LoadFile($devices_file);
}

foreach my $device_name (@device_code_list) {
	my $code = LS30::Type::getCode('Device Code', $device_name);

	foreach my $device_number (qw(00 01 02 03 04 05 06 07 08 09)) {
		my $cmd = sprintf("!k%s?%2s&", $code, $device_number);
		my $response = $ls30cmdr->sendCommand($cmd);

		if ($response =~ /^!k.000/) {

			# No device, stop looking
			last;
		}

		if ($response =~ /!k.(..)(......)(....)(..)(..)(..)(........)(.+)&/) {
			my ($dev_type, $dev_id, $junk2, $junk3, $z, $c, $config, $rest) = ($1, $2, $3, $4, $5, $6, $7, $8);
			$s2 .= join(' ', $1, $2, $3, $4, $5, $6, $7, $8) . "\n";

			my $dev_type_string = LS30::Type::getString('Device Specific Type', $dev_type);

			$s .= sprintf("%s type %s %s %s-%s ID is %s\n",
				$device_number,
				$device_name,
				$dev_type_string,
				$z,
				$c,
				$dev_id,
			);

			if (!exists $devs->{$dev_id}) {

				# Add a template to the device list
				my $hr = {
					name => 'Sample',
					number => $device_number,
					type => $dev_type_string,
					zone => sprintf("%s-%s", $z, $c),
				};
				bless $hr, 'LS30::Device';

				$devs->{$dev_id} = $hr;
				printf("Added device number %s id %s type %s\n", $device_number, $dev_id, $dev_type_string);
			} else {
				$devs->{$dev_id}->{number} = $device_number;
			}

			$dev_seen->{$dev_id} = 1;

			my $hr = LS30Command::parseDeviceConfig($config);
			if ($hr && $opt_v) {
				$s .= Data::Dumper::Dumper($hr);
			}
		}
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

print $s;
print $s2;

exit(0);
