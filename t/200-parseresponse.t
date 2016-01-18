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
			action => 'query',
			string => '!s64&',
			title  => 'Switch 1',
			value  => 4,
		},
	},

	'Auto Answer Ring Count' => {
		expect => {
			title  => 'Auto Answer Ring Count',
			action => 'query',
			string => '!a00c&',
			value  => 12,
		},
	},

	'RF Jamming Warning' => {
		expect => {
			action => 'query',
			string => '!c00&',
			title  => 'RF Jamming Warning',
			value  => 'Disabled',
		},
	},

	'Mode Change Chirp' => {
		expect => {
			action => 'query',
			string => '!m30&',
			title  => 'Mode Change Chirp',
			value  => 0,
		},
	},

	'ROM Version' => {
		expect => {
			action => 'query',
			string => '!vn05.00 09/29/09 E*F&',
			title  => 'ROM Version',
			value  => '05.00 09/29/09 E*F',
		},
	},

	'Telephone Burglar' => {
		expect => {
			action => 'query',
			string => '!t5no&',
			title  => 'Telephone Burglar',
			value  => '',
		},
	},

	# GSM commands
	'GSM Phone 1' => {
		expect => {
			action => 'query',
			string => '!g00412345678&',
			title  => 'GSM Phone 1',
			value  => '0412345678',
		},
	},

	# Special commands
	'Date/Time' => {
		expect => {
			action => 'query',
			date   => '2016-01-18',
			dow    => 'Mon',
			string => '!dt16011811450&',
			time   => '14:50:00',
			title  => 'Date/Time',
		},
	},

	'Operation Mode' => {
		expect => {
			action => 'query',
			string => '!n00&',
			title  => 'Operation Mode',
			value  => 'Disarm',
		},
	},

	'Device Count' => {
		expect => {
			action => 'query',
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
			action => 'query',
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
			action => 'query',
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
