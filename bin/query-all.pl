#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Query all known settings and print responses
#
#   Options:
#     -h host:port          Specify LS30 server host:port

use strict;

use Data::Dumper qw(Dumper);
use Getopt::Std qw(getopts);

use LS30Command qw();
use LS30Connection qw();

use vars qw($opt_h);

getopts('h:');

my $ls30c = LS30Connection->new($opt_h);

$ls30c->Connect();

LS30Command::addCommands();

my $data = { };

foreach my $title (LS30Command::listCommands()) {

	my $cmd_spec = LS30Command::getCommand($title);

	if (! $cmd_spec) {
		# Unknown title?
		next;
	}

	if ($cmd_spec->{array2}) {
		my $min = $cmd_spec->{array2}->{min};
		my $max = $cmd_spec->{array2}->{max};
		foreach my $n ($min .. $max) {
			my $query = LS30Command::queryString($cmd_spec, '', $n);
			my $response = $ls30c->sendCommand($query);
			$data->{"$title $n"} = $response;
		}
	} else {
		my $query = LS30Command::queryString($cmd_spec);
		my $response = $ls30c->sendCommand($query);
		$data->{$title} = $response;
	}
}

foreach my $title (sort (keys %$data)) {
	my $response = $data->{$title};

	printf("%-40s | %s\n", $title, $response);
}

exit(0);
