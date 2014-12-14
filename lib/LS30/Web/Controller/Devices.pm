#!/usr/bin/perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#  URIs:
#    /devices         Return a list of device types and counts
#    /devices/:type   Return details of all devices of that type

=head1 NAME

LS30::Web::Controller::Devices - Interaction with input devices (Sensors, Controllers)

This is a subclass of 'LS30::Web::Controller::Base'.

=head1 METHODS

=over

=cut

package LS30::Web::Controller::Devices;

use Mojo::Base 'LS30::Web::Controller::Base';

# ---------------------------------------------------------------------------

=item I<list()>

Return a list of device types and counts for each.

URI: /devices

=cut

sub list {
	my ($self) = @_;

	my $json = {};

	my @types = LS30::Type::listStrings('Device Type');

	foreach my $type (@types) {
		my $cmd = LS30Command::queryCommand({title => 'Device Count', device_type => $type});
		if (!$cmd) {
			return $self->render(status => 500, json => {error => "Unable to get Device Count command for $type"});
		}

		my $resp_obj = $self->sendCommand($cmd);

		if (!$resp_obj) {
			return $self->render(status => 500, json => {error => "No response received"});
		}

		$json->{$type}->{count} = $resp_obj->value;
	}

	$self->render(json => $json);
}

# ---------------------------------------------------------------------------

=item I<list_type()>

Return details of every registered device of that type

URI: /devices/:type

=cut

sub list_type {
	my ($self) = @_;

	my $json = {};
	my $type = $self->stash('type');

	my $device_type_code = LS30::Type::getCode('Device Type', $type);

	if (!defined $device_type_code) {
		return $self->render(status => 404, json => {error => "No such device type $type" });
	}

	my $cmd = LS30Command::queryCommand({title => 'Device Count', device_type => $type});
	if (!$cmd) {
		return $self->render(status => 500, json => {error => "Unable to get Device Count command"});
	}

	my $resp_obj = $self->sendCommand($cmd);
	if (!$resp_obj) {
		return $self->render(status => 500, json => {error => "No response received"});
	}

	my $device_count = $resp_obj->value;

	if ($device_count > 0) {
		my $device_code = LS30::Type::getCode('Device Code', $type);

		if (!defined $device_code) {
			return $self->render(status => 404, json => {error => "No such device code for $type" });
		}

		foreach my $device_number (0 .. $device_count - 1) {
			my $cmd = sprintf("!k%s?%2d&", $device_code, $device_number);
			my $response = $self->sendCommand($cmd);

			if (!$response) {
				return $self->render(status => 500, json => {error => "No response received"});
			}

			my $device_id = $response->get('device_id');
			my $hash = $response->to_hash;

			# Remove unwanted extra keys from output
			delete $hash->{$_} for ('action', 'string', 'title');

			$json->{$device_id} = $hash;
		}
	}

	$self->render(json => $json);
}

1;
