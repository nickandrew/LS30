#!/usr/bin/env perl
#
#  Test LS30Command::parseResponse

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Test::More qw(no_plan);

use LS30Command qw();

LS30Command::addCommands();

my $tests = {

	# Simple commands
	'Switch 1' => {
		expect => {
			action => 'value',
			string => '!s64&',
			title  => 'Switch 1',
			value  => 4,
		},
	},

	'Auto Answer Ring Count' => {
		expect => {
			title  => 'Auto Answer Ring Count',
			action => 'value',
			string => '!a00c&',
			value  => 12,
		},
	},

	'RF Jamming Warning' => {
		expect => {
			action => 'value',
			string => '!c00&',
			title  => 'RF Jamming Warning',
			value  => 'Disabled',
		},
	},

	'Mode Change Chirp' => {
		expect => {
			action => 'value',
			string => '!m30&',
			title  => 'Mode Change Chirp',
			value  => 0,
		},
	},

	'ROM Version' => {
		expect => {
			action => 'value',
			string => '!vn05.00 09/29/09 E*F&',
			title  => 'ROM Version',
			value  => '05.00 09/29/09 E*F',
		},
	},

	'Telephone Burglar' => {
		expect => {
			action => 'value',
			string => '!t5no&',
			title  => 'Telephone Burglar',
			value  => '',
		},
	},

	# GSM commands
	'GSM Phone 1' => {
		expect => {
			action => 'value',
			string => '!g00412345678&',
			title  => 'GSM Phone 1',
			value  => '0412345678',
		},
	},

	# Special commands
	'Date/Time' => {
		expect => {
			action => 'value',
			date   => '2016-01-18',
			dow    => 'Mon',
			string => '!dt16011811450&',
			time   => '14:50:00',
			title  => 'Date/Time',
		},
	},

	'Operation Mode' => {
		expect => {
			action => 'value',
			string => '!n00&',
			title  => 'Operation Mode',
			value  => 'Disarm',
		},
	},

	'Device Count' => {
		expect => {
			action => 'value',
			string => '!b307&',
			title  => 'Device Count',
			value  => 7,
		},
	},

	# Learn commands
	'Learn Burglar Sensor' => {
		expect => {
			action => 'query',
			string => '!ibl?&',
			title  => 'Learn Burglar Sensor',
		},
	},

	'Added Burglar Sensor' => {
		expect => {
			action => 'value',
			config => '04100000',
			id     => '06',
			index  => 7,
			string => '!ibl07010604100000&',
			title  => 'Added Burglar Sensor',
			zone   => '01',
		},
	},

	# Delete commands
	'Delete Burglar Sensor' => {
		expect => {
			action => 'value',
			string => '!ibk07&',
			title  => 'Delete Burglar Sensor',
		},
	},
};

foreach my $test_name (sort (keys %$tests)) {
	my $t = $tests->{$test_name};

	if ($t->{expect}) {
		my $hr = LS30Command::parseResponse($t->{expect}->{string});
		is_deeply($hr, $t->{expect}, $test_name)
		  or print $test_name, '-' x 30, "\n", Dumper($hr);
		next;
	}
}

exit(0);
