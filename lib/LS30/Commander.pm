#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

=head1 NAME

LS30::Commander - Send commands to LS30

=head1 DESCRIPTION

This class implements a simple command/response engine for the LS30.
It can send a command and then wait several seconds for a response.

=head1 METHODS

=over

=cut

package LS30::Commander;

use strict;
use warnings;

use LS30::Device qw();
use LS30::Log qw();
use LS30::ResponseMessage qw();

# ---------------------------------------------------------------------------

=item I<new($ls30c, $timeout)>

Return a new LS30::Commander using the specified connection, which
is of class LS30Connection.

Timeout is optional, if >0 then it specifies how many seconds at most
to wait for a response. The default timeout is 5 seconds.

=cut

sub new {
	my ($class, $ls30c, $timeout) = @_;

	my $self = {
		command_queue => [],      # Queue of pending commands and callbacks
		ls30c         => $ls30c,  # Connection to LS30 device
	};

	if (defined $timeout && $timeout > 0) {
		$self->{timeout} = $timeout;
	} else {
		$self->{timeout} = 5;
	}

	bless $self, $class;

	$ls30c->onConnect(sub {

		# Send a pending command, if any
		if ($self->{command_queue}->[0]) {
			my $lr = $self->{command_queue}->[0];
			my ($cmd, $cv, $timeout) = @$lr;
			LS30::Log::debug("Connect callback: sending queued command $cmd");
			$self->_sendCommand($cmd, $timeout);
		}
		else {
			LS30::Log::debug("Connect callback: nothing to send");
		}
	});

	$ls30c->onMINPIC(sub {
		my ($string) = @_;

		if ($self->{on_minpic}) {
			$self->{on_minpic}->($string);
		}
	});

	$ls30c->onXINPIC(sub {
		my ($string) = @_;

		if ($self->{on_xinpic}) {
			$self->{on_xinpic}->($string);
		}
	});

	$ls30c->onResponse(sub { $self->handleResponse(@_); });

	return $self;
}


# ---------------------------------------------------------------------------
# Send a command to the device.
# ---------------------------------------------------------------------------

sub _sendCommand {
	my ($self, $string, $timeout) = @_;

	my $ls30c  = $self->{ls30c};

	LS30::Log::debug("Sent: $string");

	$ls30c->send($string);

	LS30::Log::debug("Setting up timer");
	$self->{response_timer} = AnyEvent->timer(
		after => $timeout,
		cb    => sub {
			LS30::Log::debug("Timer callback");
			$self->handleResponse(undef);
		},
	);
}


# ---------------------------------------------------------------------------

=item I<queueCommand($string [, $timeout])>

Queue the supplied command to be sent to the device.

Return a condvar which will receive the response string
(or undef on timeout or error).

=cut

sub queueCommand {
	my ($self, $string, $timeout) = @_;

	$timeout ||= $self->{timeout};

	my $cv = AnyEvent->condvar;

	# If:
	#   presently connected
	#   not required to always queue the command
	#   no command outstanding
	# Then: send the command immediately
	if ($self->{ls30c}->isConnected() && !$self->{always_queue_command} && (!$self->{command_queue} || !@{$self->{command_queue}})) {
		$self->{command_queue} = [];
		$self->_sendCommand($string, $timeout);
	}

	# Queue up the command and associated callback
	push(@{$self->{command_queue}}, [$string, $cv, $timeout]);

	return $cv;
}


# ---------------------------------------------------------------------------

=item I<sendCommand($string [, $timeout])>

Deprecated method, as it is synchronous.

Send a command to the LS30 and return the associated response
as a string.

Return undef if no response was received after a timeout.

=cut

sub sendCommand {
	my ($self, $string, $timeout) = @_;

	LS30::Log::debug("Commander: sendCommand($string)");
	my $cv = $self->queueCommand($string, $timeout);

	my $response = $cv->recv();

	if (!defined $response) {
		# Timeout
		LS30::Log::debug("Timeout or error on sendCommand wait for response");
	}

	return $response;
}


# ---------------------------------------------------------------------------

=item I<onMINPIC($cb)>

SetGet callback $cb on every MINPIC received.

=cut

sub onMINPIC {
	my $self = shift;

	if (scalar @_) {
		$self->{on_minpic} = shift;
		return $self;
	}

	return $self->{on_minpic};
}


# ---------------------------------------------------------------------------

=item I<onXINPIC($cb)>

Set callback $cb on every XINPIC received.

=cut

sub onXINPIC {
	my ($self, $cb) = @_;

	$self->{on_xinpic} = $cb;

	return $self;
}


# ---------------------------------------------------------------------------

=item I<onCONTACTID($cb)>

SetGet callback $cb on every CONTACTID received.

=cut

sub onCONTACTID {
	my $self = shift;

	$self->{ls30c}->onCONTACTID(@_);
}

# ---------------------------------------------------------------------------
# Send a response back to whatever code issued a command, via condvar.
# A guard ('always_queue_command') is put around the send() call, in case
# the code run by send() issues another command, which is highly likely.
# That will force the next command to be queued, and the caller of
# _sendResponse is expected to dequeue and send the command.
# ---------------------------------------------------------------------------

sub _sendResponse {
	my ($self, $string) = @_;

	my $lr = shift(@{$self->{command_queue}});
	my ($cmd, $cv) = @$lr;
	# $cmd was the command which is being responded-to so it is not needed

	# Put a guard around send(), in case there is no queued command *and*
	# the code run by send() adds one. Without the guard, the command will
	# be both sent and queued (and sent again just below). With the guard,
	# the command will be queued and sent only once, below.
	$self->{always_queue_command} = 1;
	$cv->send($string);
	$self->{always_queue_command} = 0;
}

# ---------------------------------------------------------------------------

=item I<handleResponse($string)>

Any response received is sent to the requestor via condvar.

=cut

sub handleResponse {
	my ($self, $string) = @_;

	if (defined $string) {
		LS30::Log::debug("Got a response: $string");
	} else {
		LS30::Log::debug("No response");
	}

	# Delete timer which catches no response
	# (As this is obviously a response to the only possible outstanding command)
	delete $self->{response_timer};

	# Send back response via condvar, if any
	if (@{$self->{command_queue}}) {
		$self->_sendResponse($string);
		# Fallthrough to send next command
	}

	# If there's a pending command, send it now
	if ($self->{command_queue}->[0]) {
		my $lr = $self->{command_queue}->[0];
		my ($cmd, $cv, $timeout) = @$lr;
		$self->_sendCommand($cmd, $timeout);
	}
}


# ---------------------------------------------------------------------------

=item I<getSetting($setting_name, $cached)>

Return a condvar which will receive
the current value of $setting_name (which is defined in LS30Command).

The received value will be undef if there's an error or timeout.

The $cached parameter is ignored.

=cut

sub getSetting {
	my ($self, $setting_name, $cached) = @_;

	my $cv = AnyEvent->condvar;

	my $hr = LS30Command::getCommand($setting_name);
	if (!defined $hr || !$hr->{is_setting}) {
		LS30::Log::error("Is not a setting: <$setting_name>");
		$cv->send(undef);
		return $cv;
	}

	my $cmd = LS30Command::queryCommand({title => $setting_name});

	my $cv2 = $self->queueCommand($cmd);
	$cv2->cb(sub {
		my $response = $cv2->recv();
		my $resp_obj = LS30::ResponseMessage->new($response);
		$cv->send($resp_obj->value);
	});

	return $cv;
}


# ---------------------------------------------------------------------------

=item I<setSetting($setting_name, $value)>

Return a condvar associated with setting
a new value for $setting_name (which is defined in LS30Command).

Return (through the condvar) undef if successful, otherwise an error message.

=cut

sub setSetting {
	my ($self, $setting_name, $value) = @_;

	my $cv = AnyEvent->condvar;

	my $hr = LS30Command::getCommand($setting_name);
	if (!defined $hr || !$hr->{is_setting}) {
		my $err = "Is not a setting: <$setting_name>";
		LS30::Log::error($err);
		$cv->send($err);
		return $cv;
	}

	# Test if the supplied value is valid (works for enumerated types)
	my $raw_value = LS30Command::testSettingValue($setting_name, $value);
	if (!defined $raw_value) {
		my $err = "Value <$value> is not valid for setting <$setting_name>";
		LS30::Log::error($err);
		$cv->send($err);
		return $cv;
	}

	my $cmd = LS30Command::setCommand({title => $setting_name, value => $value});

	my $cv2 = $self->queueCommand($cmd);
	$cv2->cb(sub {
		my $response = $cv2->recv();
		if (!defined $response) {
			$cv->send("Timeout");
		} else {
			my $resp_obj = LS30::ResponseMessage->new($response);
			if (!$resp_obj) {
				$cv->send("Unparseable response <$response>");
			} elsif ($resp_obj->get('error')) {
				$cv->send($resp_obj->get('error'));
			} else {
				# Success
				$cv->send(undef);
			}
		}
	});

	return $cv;
}


# ---------------------------------------------------------------------------

=item I<clearSetting($setting_name)>

Return a condvar associated with clearing
the value for $setting_name (which is defined in LS30Command).

Return (through the condvar) undef if OK, otherwise an error message.

=cut

sub clearSetting {
	my ($self, $setting_name) = @_;

	my $cv = AnyEvent->condvar;

	my $hr = LS30Command::getCommand($setting_name);
	if (!defined $hr || !$hr->{is_setting}) {
		my $err = "Is not a setting: <$setting_name>";
		LS30::Log::error($err);
		$cv->send($err);
		return $cv;
	}

	my $cmd = LS30Command::clearCommand({title => $setting_name});

	my $cv2 = $self->queueCommand($cmd);
	$cv2->cb(sub {
		my $response = $cv2->recv();
		if (!defined $response) {
			$cv->send("Timeout");
		} else {
			my $resp_obj = LS30::ResponseMessage->new($response);
			if (!$resp_obj) {
				$cv->send("Unparseable response <$response>");
			} elsif ($resp_obj->get('error')) {
				$cv->send($resp_obj->get('error'));
			} else {
				# Success
				$cv->send(undef);
			}
		}
	});

	return $cv;
}


# ---------------------------------------------------------------------------

=item I<getDeviceCount($device_type, $cached)>

Return a condvar which will return the count of how many devices of the
specified type are registered.

Condvar receives undef on an error.

=cut

sub getDeviceCount {
	my ($self, $device_type, $cached) = @_;

	my $cv = AnyEvent->condvar;

	my $query = {title => 'Device Count', device_type => $device_type};
	my $cmd = LS30Command::queryCommand($query);

	if (!$cmd) {
		# Possibly the device_type is invalid.
		LS30::Log::error("Unable to query device count for type <$device_type>");
		$cv->send(undef);
		return $cv;
	}

	my $cv2 = $self->queueCommand($cmd);
	$cv2->cb(sub {
		my $response = $cv2->recv();
		if (!$response) {
			$cv->send(undef);
		} else {
			my $resp_obj = LS30::ResponseMessage->new($response);
			$cv->send($resp_obj->value());
		}
	});

	return $cv;
}


# ---------------------------------------------------------------------------

=item I<getDeviceStatus($device_type, $device_index)>

Get the status of the specified device (specified by device_type and device_index)

Return (through a condvar) an instance of LS30::Device, or undef if error.

=cut

sub getDeviceStatus {
	my ($self, $device_type, $device_index) = @_;

	my $cv = AnyEvent->condvar;

	my $cmd = LS30Command::getDeviceStatus($device_type, $device_index);

	my $cv2 = $self->queueCommand($cmd);
	$cv2->cb(sub {
		my $resp2 = $cv2->recv();
		if (!$resp2) {
			$cv->send(undef);
		} else {
			my $resp2_obj = LS30::ResponseMessage->new($resp2);
			my $device = LS30::Device->newFromResponse($resp2_obj, $device_type, $device_index);
			$cv->send($device);
		}
	});

	return $cv;
}


# ---------------------------------------------------------------------------

=item I<getDeviceByZoneId($device_type, $zone, $id)>

Retrieve the specified device (specified by device_type and zone and id)

Return (through a condvar) an instance of LS30::Device, or undef if error.

=cut

sub getDeviceByZoneId {
	my ($self, $device_type, $zone, $id) = @_;

	my $cv = AnyEvent->condvar;

	my $cmd = LS30Command::getDeviceByZoneId($device_type, $zone, $id);

	my $cv2 = $self->queueCommand($cmd);
	$cv2->cb(sub {
		my $resp = $cv2->recv();
		if (!$resp) {
			$cv->send(undef);
		} else {
			my $resp_obj = LS30::ResponseMessage->new($resp);
			my $device = LS30::Device->newFromResponse($resp_obj, $device_type, $resp_obj->get('index'));
			$cv->send($device);
		}
	});

	return $cv;
}

=back

=cut

1;
