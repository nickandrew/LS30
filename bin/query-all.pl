#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Query all known settings and print responses
#
#   Options:
#     -h host:port          Specify LS30 server host:port
#     -s filename           Save queries and responses to YAML file

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Getopt::Std qw(getopts);
use YAML qw();

use LS30::Commander qw();
use LS30::ResponseMessage qw();
use LS30::Type qw();
use LS30Command qw();
use LS30Connection qw();

use vars qw($opt_h $opt_s);

getopts('h:s:');

{
	no warnings;
	$Data::Dumper::Sortkeys = 1;
}

my $ls30c = LS30Connection->new($opt_h);

$ls30c->connect();

LS30Command::addCommands();

my $ls30cmdr = LS30::Commander->new($ls30c);

my @data;

foreach my $title (sort (LS30Command::listCommands())) {

	my $cmd_spec = LS30Command::getCommand($title);

	if (!$cmd_spec) {

		# Unknown title?
		next;
	}

	my $cmd_ref = {
		title => $title,
	};

	if ($cmd_spec->{query_args}) {
		permuteArgs($cmd_spec->{query_args}, $cmd_ref, $title);
	} else {
		my $query    = LS30Command::queryCommand($cmd_ref);
		my $response = $ls30cmdr->sendCommand($query);

		my $hr = {
			title    => $title,
			query    => $query,
			response => $response,
		};

		push(@data, $hr);
	}
}

foreach my $hr (@data) {

	my $response = $hr->{response};

	if ($response) {
		printf("%-40s | %s\n", $hr->{title}, $response);
		my $resp = LS30::ResponseMessage->new($response);
		print Dumper($resp) if ($resp);
	}
}

if ($opt_s) {
	YAML::DumpFile($opt_s, \@data);
}

exit(0);

# ---------------------------------------------------------------------------
# A query command takes arguments. It may take more than one. We assume that
# all arguments are one of a finite set, and we iterate through all
# permutations of their values.
# This is a recursive function.
# ---------------------------------------------------------------------------

sub permuteArgs {
	my ($query_args, $cmd_ref, $title) = @_;

	if (!@$query_args) {

		# Recursion has finished; issue command
		my $cmd  = LS30Command::queryCommand($cmd_ref);
		my $resp = $ls30cmdr->sendCommand($cmd);

		# Save response
		my $hr = {
			title    => $title,
			query    => $cmd,
			response => $resp,
		};

		push(@data, $hr);
		return;
	}

	my @rest = @$query_args;
	my $arg  = shift @rest;
	my $type = $arg->{type};

	if (!$type) {

		# This is normal. This command takes arguments which can't be enumerated
		warn "permuteArgs: no 'type' defined for $title, key $arg->{key}\n";
		return;
	}

	my @list = LS30::Type::listStrings($arg->{type});
	my $key  = $arg->{key};

	foreach my $v (@list) {
		$cmd_ref->{$key} = $v;
		permuteArgs(\@rest, $cmd_ref, "$title $key=$v");
	}
}
