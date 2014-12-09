#!/usr/bin/perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

package LS30::Web::Controller::Devices;

use Mojo::Base 'LS30::Web::Controller::Base';

sub list {
	my ($self) = @_;

	my $json = {};

	my @types = LS30::Type::listStrings('Device Type');

	foreach my $type (@types) {
		my $cmd = LS30Command::queryCommand({title => 'Device Count', device_type => $type});
		if ($cmd) {
			my $resp_obj = $self->sendCommand($cmd);

			if ($resp_obj) {
				my $v = $resp_obj->value;
				$json->{'Device Count'}->{$type} = $v;
			}
		}
	}

	$self->render(json => $json);
}

1;
