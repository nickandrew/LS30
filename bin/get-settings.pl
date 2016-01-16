#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Retrieve and print named settings

use strict;
use warnings;

use Getopt::Std qw(getopts);

use LS30Command qw();
use LS30Connection qw();
use LS30::Commander qw();

LS30Command::addCommands();

my $ls30c = LS30Connection->new();

$ls30c->connect();

my $ls30cmdr = LS30::Commander->new($ls30c, 5);

my $guard = AnyEvent->condvar;
$guard->begin();

foreach my $setting_name (@ARGV) {
	$guard->begin();
	my $cv = $ls30cmdr->getSetting($setting_name);
	$cv->cb(sub {
		my $value = $cv->recv;

		if (defined $value) {
			printf("%-20s | %s\n", $setting_name, $value);
		} else {
			print STDERR "No value for '$setting_name'\n";
		}
		$guard->end();
	});
}

$guard->end;
$guard->recv;

exit(0);
