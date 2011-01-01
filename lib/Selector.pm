#!/usr/bin/perl -w
#   vim:sw=4:ts=4:
#   Copyright (C) 2010, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3
#
#  Event Controller using select() and watchdog timeouts

=head1 NAME

Selector - Select loop and event generator

=head1 DESCRIPTION

A Selector's primary role is to loop forever calling select() on
some file descriptors, and perform processing on those file descriptors
which are ready for reading.

In addition, a Selector has a set of timer objects and it triggers events
to those objects whenever their timers expire.

To do this it checks all timer objects each time through the select loop:

=over

=item

All timer objects with expired timeouts have an event occur (the
class calls an object method).

=item

The timer object with the shortest future timeout determines how
long the select() loop will block, at most. This ensures that the select
loop will trigger an event (as per above) in this timer object close to
the timeout time.

=item

Otherwise, a maximum of 60 seconds wait time is used.

=back

=head1 METHODS

=over

=cut

package Selector;

use strict;

use IO::Select qw();


# ---------------------------------------------------------------------------

=item new()

Construct a new object and return it. Initially, the object has an
empty set of timers and empty IO::Select object.

=cut

sub new {
	my ($class) = @_;

	my $self = {
		'timers' => [ ],
		'select' => IO::Select->new(),
		'sockets' => 0,
	};

	bless $self, $class;

	return $self;
}


# ---------------------------------------------------------------------------

=item addSelect($lr)

Add an array to the IO::Select object. The array is expected to have 2
elements: [ socket_ref, object_ref ]

=cut

sub addSelect {
	my ($self, $lr) = @_;

	$self->{'select'}->add($lr);
	$self->{'sockets'} ++;
}


# ---------------------------------------------------------------------------

=item addObject($object)

Add an object which will be selected on and/or timed.

=cut

sub addObject {
	my ($self, $object) = @_;

	if ($object->can('socket')) {
		my $socket = $object->socket();
		$self->{'select'}->add( [$socket, $object] );
		$self->{'sockets'} ++;
	}

	# If the object is also a Timer, add it to the timers
	if ($object->isa('Timer')) {
		$self->addTimer($object);
	}
}


# ---------------------------------------------------------------------------

=item removeSelect($lr)

Remove the specified socket from the IO::Select object.
The argument can be either a socket reference, or an array reference with
2 elements: [ socket_ref, object_ref ].

=cut

sub removeSelect {
	my ($self, $lr) = @_;

	my $select = $self->{'select'};
	if ($select->exists($lr)) {
		$select->remove($lr);
		$self->{'sockets'} --;
	}
}


# ---------------------------------------------------------------------------

=item addTimer($obj)

Add the specified timer reference to our list of timers.
The reference is an object of class Timer or subclass.

=cut

sub addTimer {
	my ($self, $obj) = @_;

	push(@{$self->{'timers'}}, $obj);
}


# ---------------------------------------------------------------------------

=item removeTimer($obj)

Remove the specified timer reference. Returns 1 if the reference was removed,
zero if it was not in the list.

=cut

sub removeTimer {
	my ($self, $obj) = @_;

	my @new_timers;
	my $found = 0;

	foreach my $r (@{$self->{'timers'}}) {
		if ($r == $obj) {
			$found = 1;
			next;
		}

		push(@new_timers, $r);
	}

	$self->{'timers'} = \@new_timers;

	return $found;
}


# ---------------------------------------------------------------------------

=item eventLoop()

Main event loop. Loops forever.

At the beginning of each loop, all timers are checked. Any expired timers
have an event generated with a call to the event function. The times
of non-expired timers are used to calculate a maximum wait time in the
select loop.

If all timers are expired then a maximum wait time of 1 second is chosen.

If the maximum wait time is longer than 60 seconds, it is set to 60.

Next, select() is called. All sockets available for read are detected.
The specified function is called like this:

    $object->handleRead($self, $socket);

=cut

sub eventLoop {
	my ($self) = @_;

	my $select = $self->{'select'};

	if (! $select) {
		die "Unable to eventLoop(): No IO::Select object";
	}

	while (1) {
		$self->pollServer(0);
	}
}


# ---------------------------------------------------------------------------

=item pollServer($timeout)

Poll sockets and timers once, with a maximum specified timeout.
All timers are checked. Any expired timers have an event generated with a
call to the event function. The times of non-expired timers are used to
calculate a maximum wait time. If an overall timeout is specified, this is
the maximum timeout.

If all timers are expired then a maximum wait time of 1 second is chosen.

If the maximum wait time is longer than 60 seconds, it is set to 60.

Next, select() is called. All sockets available for read are detected.
The specified function is called like this:

    $object->handleRead($self, $socket);

=cut

sub pollServer {
	my ($self, $timeout) = @_;

	my $select = $self->{'select'};

	if (! $select) {
		die "Unable to pollServer(): No IO::Select object";
	}

	my $how_long = $self->runTimers();

	if ($timeout && $timeout < $how_long) {
		$how_long = $timeout;
	}

	if (! $self->{sockets}) {
		# No sockets, just wait a bit
		sleep($how_long);
		return;
	}

	my @read = $select->can_read($how_long);

	if (@read) {
		foreach my $handle (@read) {
			if (ref($handle) ne 'ARRAY') {
				warn "Read handle $handle is not an array!\n";
				next;
			}

			my ($socket, $object) = @$handle;

			if (! $object) {
				warn "Unable to call handleRead() on undefined object\n";
			} else {
				$object->handleRead($self, $socket);
			}

		}
	}
}


# ---------------------------------------------------------------------------

=item runTimers()

Check all timers and generate events on all expired timers.

All non-expired timers are used to choose how long select() should block
for, at most.

An enhancement would be that the timeout is checked again immediately after
an event is generated.

=cut

sub runTimers {
	my ($self) = @_;

	my $timers = $self->{'timers'};

	my $now = time();
	my $wait_til = undef;

	foreach my $ref (@$timers) {

		my $t = $ref->watchdogTime($self);

		if (defined $t && $t <= $now) {
			$ref->watchdogEvent($self);
			$t = $ref->watchdogTime($self);
		}

		if (defined $t && (! defined $wait_til || $t < $wait_til)) {
			$wait_til = $t;
		}
	}

	if (!defined $wait_til) {
		return 120;
	}

	my $how_long = $wait_til - $now;
	if ($how_long == 0) {
		$how_long = 1;
	}
	elsif ($how_long > 60) {
		$how_long = 60;
	}

	return $how_long;
}

1;
