#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

=head1 NAME

LS30::Log

=head1 DESCRIPTION

Useful logging functions.

=head1 METHODS

=over

=cut

package LS30::Log;

use strict;

use Date::Format qw(time2str);


# ---------------------------------------------------------------------------

=item logFormat($string)

Format a supplied string:

  - Make CR and LF visible
  - Prefix with current date and time
  - Append a newline.

Return the formatted string.

=cut

sub logFormat {
	my ($string) = @_;

	my $now = time();

	$string =~ s/\\/\\\\/sg;
	$string =~ s/\r/\\r/sg;
	$string =~ s/\n/\\n/sg;
	return time2str('%Y-%m-%d %T ', $now) . $string . "\n";
}


# ---------------------------------------------------------------------------

=item timePrint($string)

Format the supplied string in the logging format then print to STDOUT.

=cut

sub timePrint {
	my ($string) = @_;

	print logFormat($string);
}

1;
