#!/usr/bin/env perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

=head1 NAME

Timer - An object which will trigger at some time

=head1 DESCRIPTION

A Selector object can have one or more Timer objects which are
used to trigger events at certain times. Each Timer keeps a
single time_t value which is the earliest time the event should
trigger. The event can trigger at any time on or after this
value.

=head1 METHODS

=over

=cut

package Timer;

use strict;
use warnings;


# ---------------------------------------------------------------------------

=item new(%args)

Instantiate a new Timer object. Arguments are:

   arg_ref            A reference. arg_ref will be passed as the first
                      argument to the event trigger function. arg_ref is
                      opaque to this class.

   func_ref           Reference to optional event trigger function.

   next_time          time_t value of the earliest time this Timer can
                      trigger. 'undef' means never trigger.

   recurring          Setup a recurring event after this many seconds.
                      Whenever this Timer is triggered, recurring is
                      added to next_time.

=cut

sub new {
	my ($class, %args) = @_;

	my $self = {
		arg_ref   => undef,    # args to pass upon trigger event
		func_ref  => undef,    # func to call to trigger
		next_time => undef,    # time of next trigger (undef means never)
		recurring => undef,    # number of seconds to re-trigger
	};

	bless $self, $class;

	foreach my $k (qw(arg_ref func_ref recurring)) {
		if (exists $args{$k}) {
			$self->{$k} = $args{$k};
		}
	}

	if ($args{next_time}) {
		$self->setNextTime($args{next_time});
	}

	return $self;
}


# ---------------------------------------------------------------------------

=item watchdogTime()

Return a time_t value of the desired triggering time. 'undef' means never.
A value in the past is acceptable.

=cut

sub watchdogTime {
	my ($self) = @_;

	my $next_time = $self->{next_time};
	return $next_time;
}


# ---------------------------------------------------------------------------

=item getNextTime()

Return the current value of next_time.

=cut

sub getNextTime {
	my ($self) = @_;

	return $self->{next_time};
}


# ---------------------------------------------------------------------------

=item setNextTime($time_t)

Set next_time to $time_t.

=cut

sub setNextTime {
	my ($self, $t) = @_;

	$self->{next_time} = $t;

	if ($t) {
		$self->{timer} = AnyEvent->timer(
			after => $t - time(),
			cb => sub {
				$self->watchdogEvent();
			}
		);
	} else {
		delete $self->{timer};
	}

	return $self;
}


# ---------------------------------------------------------------------------

=item setDelay($interval)

Set next_time to the current time plus $interval.

=cut

sub setDelay {
	my ($self, $interval) = @_;

	my $next_time = $self->{next_time};

	if ($next_time) {
		$self->setNextTime($next_time + $interval);
	} else {
		$self->setNextTime(time() + $interval);
	}
}


# ---------------------------------------------------------------------------

=item getArgs()

Return the current value of arg_ref.

=cut

sub getArgs {
	my ($self) = @_;

	return $self->{arg_ref};
}


# ---------------------------------------------------------------------------

=item setArgs($arg_ref)

Set arg_ref.

=cut

sub setArgs {
	my ($self, $arg_ref) = @_;

	$self->{arg_ref} = $arg_ref;
}


# ---------------------------------------------------------------------------

=item setFunction($func_ref)

Set func_ref.

=cut

sub setFunction {
	my ($self, $func_ref) = @_;

	$self->{func_ref} = $func_ref;
}


# ---------------------------------------------------------------------------

=item stop()

Set next_time to undef. This will stop the timer triggering.

=cut

sub stop {
	my ($self) = @_;

	$self->setNextTime(undef);
}


# ---------------------------------------------------------------------------

=item watchdogEvent()

Called upon the triggering of this timer.

First, stop the timer so it will not trigger again (until next_time is
set to some time_t value).

If func_ref is set, then call the function like this:

   &$func_ref($ref);

=cut

sub watchdogEvent {
	my ($self) = @_;

	my $func_ref = $self->{func_ref};
	my $ref      = $self->{arg_ref};

	if ($self->{recurring}) {
		$self->setDelay($self->{recurring});
	} else {
		$self->stop();
	}

	if ($func_ref) {
		&$func_ref($ref);
	}
}

1;
