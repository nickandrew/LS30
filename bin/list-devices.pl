#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Print a list of known devices.

use Data::Dumper qw(Dumper);
use Getopt::Std qw(getopts);

use LS30Command qw();
use LS30Connection qw();

use vars qw($opt_h);

getopts('h:');

my $ls30c = LS30Connection->new($opt_h);

$ls30c->Connect();

LS30Command::addCommands();

my @responses;

my $types = {
	'Burglar Sensor' => 'b',
	'Controller' => 'c',
	'Fire Sensor' => 'f',
	'Medical Button' => 'm',
	'Extra Sensor' => 'e',
};

my $s = '';
my $s2 = '';

foreach my $type (sort (keys %$types)) {
	my $code = $types->{$type};

	foreach my $device_number qw(00 01 02 03 04 05 06 07 08 09) {
		my $cmd = sprintf("!k%s?%2s&", $code, $device_number);
		my $response = $ls30c->sendCommand($cmd);

		if ($response =~ /^!k.000/) {
			# No device, stop looking
			last;
		}

		if ($response =~ /!k.(..)(......)(....)(..)(..)(..)(........)(.+)/) {
			my ($junk1, $dev_id, $junk2, $junk3, $z, $c, $config, $rest) = ($1, $2, $3, $4, $5, $6, $7, $8);

			$s .= sprintf("%s %s-%s ID is %s\n",
				$type,
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
