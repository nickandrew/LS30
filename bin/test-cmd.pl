#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#   Test command generation - output command string and hashref to STDOUT

use Data::Dumper qw(Dumper);
use Getopt::Std qw(getopts);

use LS30Command qw();

use vars qw($opt_q $opt_s);

getopts('qs');

if (! $opt_q && ! $opt_s) {
	die "Need to specify either option -q or -s";
}

if ($opt_q && $opt_s) {
	die "Cannot specify both options -q and -s";
}

my $title = shift @ARGV || die "Need to specify title";

LS30Command::addCommands();

my $cmd_hr = { title => $title };

foreach my $arg (@ARGV) {
	if ($arg =~ /^([^=]+)=(.+)/) {
		my ($k, $v) = ($1, $2);

		$cmd_hr->{$k} = $v;
	}
}

my $cmd;

if ($opt_q) {
	$cmd = LS30Command::queryCommand($cmd_hr);
} else {
	$cmd = LS30Command::setCommand($cmd_hr);
}

print Data::Dumper::Dumper($cmd_hr);
print "Cmd: $cmd\n";

exit(0);
