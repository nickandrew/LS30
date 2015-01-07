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

	$ls30c->setHandler($self);

	return $self;
}


# ---------------------------------------------------------------------------
# Send a command to the device.
# ---------------------------------------------------------------------------

sub _sendCommand {
	my ($self, $string) = @_;

	my $ls30c  = $self->{ls30c};
	my $socket = $ls30c->socket();

	if (!$socket) {
		die "Unable to _sendCommand(): Not connected";
	}

	$socket->send($string);
	if ($ENV{LS30_DEBUG}) {
		LS30::Log::timePrint("Sent: $string");
	}
}


# ---------------------------------------------------------------------------

=item I<queueCommand($string)>

Queue the supplied command to be sent to the device.

Return a condvar which will receive the response string
(or undef on timeout or error).

=cut

sub queueCommand {
	my ($self, $string) = @_;

	my $cv = AnyEvent->condvar;

	# If there's presently no command outstanding, send the command immediately
	if (!$self->{always_queue_command} && (!$self->{command_queue} || !@{$self->{command_queue}})) {
		$self->{command_queue} = [];
		$self->_sendCommand($string);
	}

	# Queue up the command and associated callback
	push(@{$self->{command_queue}}, [$string, $cv]);

	return $cv;
}


# ---------------------------------------------------------------------------

=item I<sendCommand($string)>

Send a command to the LS30 and wait up to $self->{timeout} seconds for a
response.  Return the first response received within this time.

Return undef if no response was received after a timeout.

=cut

sub sendCommand {
	my ($self, $string) = @_;

	my $cv = $self->queueCommand($string);

	my $response = $cv->recv();

	if (!defined $response) {
		# Timeout
		LS30::Log::timePrint("Timeout or error on on sendCommand wait for response");
	}

	return $response;
}


# ---------------------------------------------------------------------------

=item I<onMINPIC($cb)>

Callback $cb on every MINPIC received.

=cut

sub onMINPIC {
	my ($self, $cb) = @_;

	$self->{on_minpic} = $cb;

	return $self;
}


# ---------------------------------------------------------------------------

=item I<handleMINPIC($string)>

Store any MINPIC string received by the poll.

=cut

sub handleMINPIC {
	my ($self, $string) = @_;

	$self->{last_minpic} = $string;

	if ($self->{on_minpic}) {
		$self->{on_minpic}->($string);
	}
}


# ---------------------------------------------------------------------------

=item I<onCONTACTID($cb)>

Callback $cb on every CONTACTID received.

=cut

sub onCONTACTID {
	my ($self, $cb) = @_;

	$self->{on_contactid} = $cb;

	return $self;
}


# ---------------------------------------------------------------------------

=item I<handleCONTACTID($string)>

Store any CONTACTID string received by the poll.

=cut

sub handleCONTACTID {
	my ($self, $string) = @_;

	$self->{last_contactid} = $string;

	if ($self->{on_contactid}) {
		$self->{on_contactid}->($string);
	}
}


# ---------------------------------------------------------------------------

=item I<handleResponse($string)>

Any response received is sent to the requestor via condvar.

=cut

sub handleResponse {
	my ($self, $string) = @_;


	# Call callback if any, and send next command
	if (@{$self->{command_queue}}) {
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

	# If there's a pending command, send it now
	if ($self->{command_queue}->[0]) {
		my $cmd = $self->{command_queue}->[0]->[0];
		$self->_sendCommand($cmd);
		# Next call to this function will send the condvar for this command.
	}
}


# ---------------------------------------------------------------------------

=item I<handleAT($string)>

Store any AT string received by the poll.

=cut

sub handleAT {
	my ($self, $string) = @_;

	$self->{last_at} = $string;
}


# ---------------------------------------------------------------------------

=item I<handleGSM($string)>

Store any GSM string received by the poll.

=cut

sub handleGSM {
	my ($self, $string) = @_;

	$self->{last_gsm} = $string;
}


# ---------------------------------------------------------------------------

=item I<handleDisconnect($string)>

This function is called if our client socket is disconnected.

=cut

sub handleDisconnect {
	my ($self) = @_;

	# Nothing to do?
}


# ---------------------------------------------------------------------------

=item I<getMINPIC()>

Return any saved MINPIC string.

=cut

sub getMINPIC {
	my ($self) = @_;

	return $self->{last_minpic};
}


# ---------------------------------------------------------------------------

=item I<getCONTACTID()>

Return any saved CONTACTID string.

=cut

sub getCONTACTID {
	my ($self) = @_;

	return $self->{last_contactid};
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
		warn "Is not a setting: <$setting_name>\n";
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

	# Test if the supplied value is valid (works for enumerated types)
	my $raw_value = LS30Command::testSettingValue($setting_name, $value);
	if (!defined $raw_value) {
		warn "Value <$value> is not valid for setting <$setting_name>\n";
		$cv->send(undef);
		return $cv;
	}

	my $cmd = LS30Command::setCommand({title => $setting_name, value => $value});

	my $cv2 = $self->queueCommand($cmd);
	$cv2->cb(sub {
		my $response = $cv2->recv();
		my $resp_obj = LS30::ResponseMessage->new($response);
		# TODO: Test the response for validity/error
		$cv->send(1);
	});

	return $cv;
}


# ---------------------------------------------------------------------------

=item I<clearSetting($setting_name)>

Return a condvar associated with clearing
the value for $setting_name (which is defined in LS30Command).

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

	my $cmd = LS30Command::clearCommand({title => $setting_name});

	my $cv2 = $self->queueCommand($cmd);
	$cv2->cb(sub {
		my $response = $cv2->recv();
		my $resp_obj = LS30::ResponseMessage->new($response);
		# TODO: Test the response for validity/error
		use Data::Dumper qw(Dumper);
		print STDERR "Response: ", Dumper($resp_obj);
		$cv->send(1);
	});

	return $cv;
}


# ---------------------------------------------------------------------------

=item I<getDeviceCount($device_type, $cached)>

Return a condvar which will return the count of how many devices of the
specified type are registered.

=cut

sub getDeviceCount {
	my ($self, $device_type, $cached) = @_;

	my $cv = AnyEvent->condvar;

	my $query = {title => 'Device Count', device_type => $device_type};
	my $cmd = LS30Command::queryCommand($query);
	if (!$cmd) {
		# Possibly the device_type is invalid.
		warn "Unable to query device count for type <$device_type>\n";
		$cv->send(undef);
		return $cv;
	}

	my $cv2 = $self->queueCommand($cmd);
	$cv2->cb(sub {
		my $response = $cv2->recv();
		my $resp_obj = LS30::ResponseMessage->new($response);
		$cv->send($resp_obj->value());
	});

	return $cv;
}


# ---------------------------------------------------------------------------

=item I<getDeviceStatus($device_type, $device_number)>

Get the status of the specified device (specified by device_type and device_number)

Return (through a condvar) an instance of LS30::Device, or undef if error.

=cut

sub getDeviceStatus {
	my ($self, $device_type, $device_number) = @_;

	my $cv = AnyEvent->condvar;

	my $cmd = LS30Command::getDeviceStatus($device_type, $device_number);

	my $cv2 = $self->queueCommand($cmd);
	$cv2->cb(sub {
		my $resp2 = $cv2->recv();
		my $resp2_obj = LS30::ResponseMessage->new($resp2);
		my $device = LS30::Device->newFromResponse($resp2_obj);
		$cv->send($device);
	});

	return $cv;
}

=back

=cut

1;
