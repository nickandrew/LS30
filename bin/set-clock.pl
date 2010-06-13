#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Set LS-30 real time clock to current time.
#   The 'seconds' part of the clock cannot be set. If option -p is used,
#   then the program waits until the minute changes before commanding the
#   device. This results in the device's clock being accurate.
#
#   Options:
#   -h host:port      Connect to the specified host:port
#   -p                Precise: wait for the minute mark before setting.

use Date::Format qw(time2str);
use Getopt::Std qw(getopts);

use LS30::Commander qw();
use LS30::ResponseMessage qw();
use LS30Command qw();
use LS30Connection qw();

use vars qw($opt_h $opt_p);

getopts('h:p');

my $ls30c = LS30Connection->new($opt_h);

$ls30c->connect();

LS30Command::addCommands();

my $ls30cmdr = LS30::Commander->new($ls30c);
my $now = time();

if ($opt_p) {
	# Wait until seconds are zero
	my $sec = time2str('%S', $now);

	if ($sec > 0) {
		printf("Waiting %d seconds until the minute mark.\n", 60 - $sec);
		$now += 60 - $sec;
		sleep(60 - $sec);
	}
}

my $hr = {
	title => 'Date/Time',
	'date' => time2str('%Y-%m-%d', $now),
	'time' => time2str('%H:%M:%S', $now),
	'dow' => time2str('%a', $now),
};

my $cmd = LS30Command::setCommand($hr);

if (!defined $cmd) {
	die "Unable to construct a command to set date/time";
}

my $response = $ls30cmdr->sendCommand($cmd);

if (! $response) {
	die "Command was sent, but no response was received";
}

printf("Sent: %-40s | Response: %s\n", $cmd, $response);
my $resp = LS30::ResponseMessage->new($response);

if (! $resp || $resp->{title} ne 'Date/Time') {
	die "Couldn't parse response\n";
}

printf("Set date/time to %s, %s %s\n", $resp->{dow}, $resp->{'date'}, $resp->{'time'});

exit(0);
