#!/usr/bin/perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

package LS30::Web::Controller::Settings;

use Mojo::Base 'LS30::Web::Controller::Base';

my $queries = {
	general => [
		{ title => 'Inner Siren Time', },
		{ title => 'Remote Siren Time', },
		{ title => 'Inner Siren Enable', },
		{ title => 'Exit Delay', },
		{ title => 'Entry Delay', },
		{ title => 'Entry delay beep', },
	],
	mode => [
		{ title => 'Operation Mode', },
	],
};

sub _simple {
	my ($self, $type) = @_;

	my $json = {};

	foreach my $hr (@{$queries->{$type}}) {
		my $cmd      = LS30Command::queryCommand($hr);
		my $resp_obj = $self->sendCommand($cmd);

		if ($resp_obj) {
			my $v = $resp_obj->value;
			$json->{$hr->{title}} = $v;
		}
	}

	$self->render(json => $json);
}

sub general {
	my $self = shift;

	$self->_simple('general');
}

sub mode {
	my $self = shift;

	$self->_simple('mode');
}

1;
