#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Print a list of known devices.

use Data::Dumper qw(Dumper);
use Getopt::Std qw(getopts);

use LS30::Commander qw();
use LS30::Type qw();
use LS30Command qw();
use LS30Connection qw();

use vars qw($opt_h);

getopts('h:');

my $ls30c = LS30Connection->new($opt_h);

$ls30c->Connect();

LS30Command::addCommands();

my $ls30cmdr = LS30::Commander->new($ls30c);

my @responses;
my @device_code_list = LS30::Type::listStrings('Device Code');

my $s = '';
my $s2 = '';

foreach my $device_name (@device_code_list) {
	my $code = LS30::Type::getCode('Device Code', $device_name);

	foreach my $device_number qw(00 01 02 03 04 05 06 07 08 09) {
		my $cmd = sprintf("!k%s?%2s&", $code, $device_number);
		my $response = $ls30cmdr->sendCommand($cmd);

		if ($response =~ /^!k.000/) {
			# No device, stop looking
			last;
		}

		if ($response =~ /!k.(..)(......)(....)(..)(..)(..)(........)(.+)&/) {
			my ($dev_type, $dev_id, $junk2, $junk3, $z, $c, $config, $rest) = ($1, $2, $3, $4, $5, $6, $7, $8);

			my $dev_type_string = LS30::Type::getString('Device Specific Type', $dev_type);

			$s .= sprintf("%s %s %s-%s ID is %s\n",
				$device_name,
				$dev_type_string,
				$z,
				$c,
				$dev_id,
			);

			my $hr = LS30Command::parseDeviceConfig($config);
			if ($hr) {
				$s .= Data::Dumper::Dumper($hr);
			}

			$s2 .= join(' ', $1, $2, $3, $4, $5, $6, $7, $8) . "\n";
		}
	}
}

print $s;
print $s2;

exit(0);
