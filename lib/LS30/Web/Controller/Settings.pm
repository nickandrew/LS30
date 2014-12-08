#!/usr/bin/perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

package LS30::Web::Controller::Settings;

use Mojo::Base 'LS30::Web::Controller::Base';

sub general {
	my $self = shift;

	my $queries = [
		{ title => 'Inner Siren Time', },
		{ title => 'Remote Siren Time', },
		{ title => 'Inner Siren Enable', },
		{ title => 'Exit Delay', },
		{ title => 'Entry Delay', },
		{ title => 'Entry delay beep', },
		{ title => 'Operation Mode', },
	];

	my $json = {};

	foreach my $hr (@$queries) {
		my $cmd_spec = LS30Command::getCommand($hr->{title});

		my $cmd      = LS30Command::queryCommand($hr);
		my $resp_obj = $self->sendCommand($cmd);

		if ($resp_obj) {
			my $v = $resp_obj->value;
			$json->{$hr->{title}} = $v;
		}
	}

	$self->render(json => $json);
}

sub mode {
	my $self = shift;

	my $cmd_ref = {title => 'Operation Mode'};
	my $cmd = LS30Command::queryCommand($cmd_ref);
	my $response = $self->sendCommand($cmd);

	$self->render(json => {mode => $response->value});
}

1;
