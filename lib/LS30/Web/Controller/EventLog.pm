#!/usr/bin/perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#  URIs:
#    /eventlog        Return 25 most recent events

=head1 NAME

LS30::Web::Controller::EventLog - LS30 event log

This is a subclass of 'LS30::Web::Controller::Base'.

=head1 METHODS

=over

=cut

package LS30::Web::Controller::EventLog;

use Mojo::Base 'LS30::Web::Controller::Base';

# ---------------------------------------------------------------------------

=item I<list()>

Return a list of events

URI: /eventlog

=cut

sub list {
	my ($self) = @_;

	my $json = {};

	my $first = $self->param('first');

	if (!defined $first) {
		$first = 0;
	} elsif ($first !~ /^\d{1,3}$/ || $first > 511) {
		return $self->render(status => 400, text => "Invalid value for 'first'");
	}

	my $last = $self->param('last');
	if (!defined $last) {
		$last = 511;
	} elsif ($last !~ /^\d{1,3}$/ || $last > 511) {
		return $self->render(status => 400, text => "Invalid value for 'last'");
	}

	my $id = $first;
	while ($id <= $last) {
		my $cmd = LS30Command::queryCommand({title => 'Event', value => $id});
		if (!$cmd) {
			return $self->render(status => 500, json => {error => "Unable to get Event Log command"});
		}

		my $resp_obj = $self->sendCommand($cmd);

		if (!$resp_obj) {
			return $self->render(status => 500, json => {error => "No response received"});
		}

		$json->{$id} = $resp_obj->to_hash;
		$id++;
	}

	$self->render(json => $json);
}

1;
