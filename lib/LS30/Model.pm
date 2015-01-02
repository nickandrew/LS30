#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

=head1 NAME

LS30::Model - A representation of an LS30 alarm system

=head1 SYNOPSIS

  #   my $model = LS30::Model->new();
  #   my $current_mode = $model->getSetting('Operation Mode')->recv;
  #   $model->setSetting('Operation Mode', 'Arm');

=head1 DESCRIPTION

This class models the internal state of an LS30 alarm system.

=head1 METHODS

=over

=cut

package LS30::Model;

use strict;
use warnings;

use LS30::Device qw();
use LS30::ResponseMessage qw();

=item I<new()>

Return a new instance of this class.

=cut

sub new {
	my ($class) = @_;

	my $self = {
		settings => {},
		devices => {},
	};

	bless $self, $class;

	return $self;
}

=item I<upstream($upstream)>

If $upstream is provided, then set the upstream object and return $self,
else return the upstream object.

=cut

sub upstream {
	my $self = shift;

	if (scalar @_) {
		$self->{upstream} = shift;
		return $self;
	}

	return $self->{upstream};
}

# ---------------------------------------------------------------------------
# Get or set a named setting
# ---------------------------------------------------------------------------

sub _setting {
	my $self = shift;
	my $setting_name = shift;

	if (scalar @_) {
		$self->{settings}->{$setting_name} = shift;
	}

	return $self->{settings}->{$setting_name};
}

=item I<getSetting($setting_name, $cached)>

Return a condvar which will receive
the current value of $setting_name (which is defined in LS30Command).

If $cached is set, a cached value may be returned, otherwise upstream is
queried and the value is cached before being returned through the condvar.

Example:

    # Synchronous code
    # my $value = $model->getSetting('Operation Mode', 1)->recv;

    # Asynchronous
    # my $cv = $model->getSetting('Operation Mode', 1);
    # $cv->cb(sub {
    #    my $value = $cv->recv;
    #    # ...
    # });

=cut

sub getSetting {
	my ($self, $setting_name, $cached) = @_;

	my $cv = AnyEvent->condvar;

	my $hr = LS30Command::getCommand($setting_name);
	if (!defined $hr || !$hr->{is_setting}) {
		print STDERR "Is not a setting: <$setting_name>\n";
		$cv->send(undef);
		return $cv;
	}

	my $key = $hr->{key};
	my $value = $self->_setting($setting_name);

	if ($cached && defined $value) {
		$cv->send($value);
		return $cv;
	}

	my $upstream = $self->upstream();

	if ($upstream) {
		my $cv2 = $upstream->getSetting($setting_name, $cached);
		$cv2->cb(sub {
			my $value = $cv2->recv;
			$self->_setting($setting_name, $value);
			$cv->send($value);
		});
		return $cv;
	}

	if (defined $value) {
		$cv->send($value);
		return $cv;
	}

	# TODO Return a default value.
	$cv->send(undef);
	return $cv;
}

=item I<setSetting($setting_name, $value)>

Return a condvar associated with setting
a new value for $setting_name (which is defined in LS30Command).

If an upstream is set, the value is always first propagated to upstream.

Return (through the condvar) undef if there was some problem, 1 otherwise.

=cut

sub setSetting {
	my ($self, $setting_name, $value) = @_;

	my $cv = AnyEvent->condvar;

	my $hr = LS30Command::getCommand($setting_name);
	if (!defined $hr || !$hr->{is_setting}) {
		warn "Is not a setting: <$setting_name>\n";
		$cv->send(undef);
		return $cv;
	}

	my $raw_value = LS30Command::testSettingValue($setting_name, $value);
	if (!defined $raw_value) {
		warn "Value <$value> is not valid for setting <$setting_name>\n";
		$cv->send(undef);
		return $cv;
	}

	my $upstream = $self->upstream();

	if ($upstream) {
		my $cv2 = $upstream->setSetting($setting_name, $value);
		$cv2->cb(sub {
			my $rc = $cv2->recv;
			if ($rc) {
				# Ok, so cache the saved value
				$self->_setting($setting_name, $value);
			}
			$cv->send($rc);
		});
		return $cv;
	}

	$self->_setting($setting_name, $value);
	$cv->send(1);
	return $cv;
}

=item I<clearSetting($setting_name)>

Return a condvar associated with clearing
the value for $setting_name (which is defined in LS30Command).

Presumably this means returning the setting to a default value.

If an upstream is set, the request is always first propagated to upstream.

Return (through the condvar) undef if there was some problem, 1 otherwise.

=cut

sub clearSetting {
	my ($self, $setting_name) = @_;

	my $cv = AnyEvent->condvar;

	my $hr = LS30Command::getCommand($setting_name);
	if (!defined $hr || !$hr->{is_setting}) {
		warn "Is not a setting: <$setting_name>\n";
		$cv->send(undef);
		return $cv;
	}

	my $key = $hr->{key};

	my $upstream = $self->upstream();

	if ($upstream) {
		my $cv2 = $upstream->clearSetting($setting_name);
		$cv2->cb(sub {
			my $rc = $cv2->recv;
			if ($rc) {
				$self->_setting($setting_name, undef);
			}
			$cv->send($rc);
		});
		return $cv;
	}

	$self->_setting($setting_name, undef);
	$cv->send(1);
	return $cv;
}

# ---------------------------------------------------------------------------
# _initDevices: Initialise all devices by querying upstream
# Returns a condvar which will 'send' when all is complete.
# ---------------------------------------------------------------------------

sub _initDevices {
	my ($self) = @_;

	my $upstream = $self->upstream;
	return 0 if (!$upstream);

	my $cv = AnyEvent->condvar;

	$cv->begin;

	# Get list of device types ('Burglar Sensor' etc)
	my @device_types = LS30::Type::listStrings('Device Type');

	foreach my $device_type (@device_types) {
		# Get count of number of this type of device
		my $query = {title => 'Device Count', device_type => $device_type};
		my $cmd = LS30Command::queryCommand($query);
		if (!$cmd) {
			warn "Unable to query device count for type <$device_type>\n";
			next;
		}

		$cv->begin;

		my $cv2 = $upstream->queueCommand($cmd);
		$cv2->cb(sub {
			my $response = $cv2->recv();
			my $resp_obj = LS30::ResponseMessage->new($response);
			my $count = $resp_obj->value;

			if ($count > 0) {
				foreach my $device_number (0 .. $count - 1) {
					my $cmd = LS30Command::getDeviceStatus($device_type, $device_number);

					$cv->begin;
					my $cv3 = $upstream->queueCommand($cmd);
					$cv3->cb(sub {
						my $resp2 = $cv3->recv();
						my $resp2_obj = LS30::ResponseMessage->new($resp2);
						my $device = LS30::Device->newFromResponse($resp2_obj);
						my $device_id = $device->device_id;
						$self->{devices}->{$device_type}->{$device_id} = $device;
						$cv->end;
					});
				}
			}

			$cv->end;
		});
	}

	$cv->end;

	# Success
	return $cv;
}


=back

=cut

1;
