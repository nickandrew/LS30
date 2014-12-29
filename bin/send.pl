#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Send raw commands and print raw responses.
#   Options:
#      -h  host:port      Specify host/port to connect
#      -v                 Verbose (decode response)

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Getopt::Std qw(getopts);

use LS30::Commander qw();
use LS30::ResponseMessage qw();
use LS30Command qw();
use LS30Connection qw();

use vars qw($opt_h $opt_v);

getopts('h:v');

my $ls30c = LS30Connection->new($opt_h);

$ls30c->connect();

LS30Command::addCommands();

my $ls30cmdr = LS30::Commander->new($ls30c);

my @responses;

foreach my $cmd (@ARGV) {
	my $response = $ls30cmdr->sendCommand($cmd);

	push(@responses, [$cmd, $response]);
}

foreach my $lr (@responses) {
	my ($cmd, $response) = @$lr;

	if ($response) {
		printf("%-40s | %s\n", $cmd, $response);
		my $resp = LS30::ResponseMessage->new($response);
		print Dumper($resp) if ($resp && $opt_v);
	}
}

exit(0);
