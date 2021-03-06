#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#  Watch the messages and react to them
#
#  Usage: watch.pl [options]
#
#  Options:
#    -c classname        Watching class to use (default is 'Watch')
#    -h host:port        Address of LS30 device or server

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Getopt::Std qw(getopts);

use AnyEvent qw();

use vars qw($opt_c $opt_h);

$| = 1;
getopts('c:h:');

my $class = $opt_c || 'Watch';

eval "require $class";
if ($@) {
	die "Unable to require class $class";
}

my $watcher = $class->new($opt_h, @ARGV);

my $condvar = AnyEvent->condvar;

# Loop forever
$condvar->recv;

exit(0);
