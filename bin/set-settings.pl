#!/usr/bin/env perl
#   Copyright (C) 2010-2016, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Set named settings.
#   Usage:
#      bin/set-settings.pl [-h host:port] 'Setting Name=value' ...

use strict;
use warnings;

use Getopt::Std qw(getopts);

use LS30Command qw();
use LS30Connection qw();
use LS30::Commander qw();
use LS30::ResponseMessage qw();

LS30Command::addCommands();

use vars qw($opt_h);

getopts('h:');

my $ls30c = LS30Connection->new($opt_h);

$ls30c->connect();

my $ls30cmdr = LS30::Commander->new($ls30c, 5);

my $guard = AnyEvent->condvar;
$guard->begin();

foreach my $instruction (@ARGV) {
	if ($instruction !~ /^([^=]+)=(.+)/) {
		print STDERR "Invalid setting=value argument: $instruction\n";
		next;
	}

	my ($setting_name, $value) = ($1, $2);

	$guard->begin();
	my $cv = $ls30cmdr->setSetting($setting_name, $value);
	$cv->cb(sub {
		my $resp_obj = $cv->recv;

		if (!defined $resp_obj) {
			printf("%-40s | FAILED\n", $setting_name);
		} else {
			my $error = $resp_obj->get('error');
			if ($error) {
				printf("%-40s | Error: %s\n", $setting_name, $error);
			} else {
				printf("%-40s | %s\n", $setting_name, $resp_obj->value);
			}
		}
		$guard->end();
	});
}

$guard->end;
$guard->recv;

exit(0);
