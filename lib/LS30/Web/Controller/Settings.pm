#!/usr/bin/perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

package LS30::Web::Controller::Settings;

use Mojo::Base 'LS30::Web::Controller::Base';

# ---------------------------------------------------------------------------
# Define all the simple settings groups.
# Each is accessed via the URL "/settings/:name"
# ---------------------------------------------------------------------------

my $simple_queries = {
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
	switches => [
		{ title => 'Switch 1' },
		{ title => 'Switch 2' },
		{ title => 'Switch 3' },
		{ title => 'Switch 4' },
		{ title => 'Switch 5' },
		{ title => 'Switch 6' },
		{ title => 'Switch 7' },
		{ title => 'Switch 8' },
		{ title => 'Switch 9' },
		{ title => 'Switch 10' },
		{ title => 'Switch 11' },
		{ title => 'Switch 12' },
		{ title => 'Switch 13' },
		{ title => 'Switch 14' },
		{ title => 'Switch 15' },
		{ title => 'Switch 16' },
	],
	modem => [
		{ title => 'Auto Answer Ring Count' },
	],
};

sub _simple {
	my ($self, $type) = @_;

	my $json = {};

	foreach my $hr (@{$simple_queries->{$type}}) {
		my $cmd      = LS30Command::queryCommand($hr);
		my $resp_obj = $self->sendCommand($cmd);

		if ($resp_obj) {
			my $v = $resp_obj->value;
			$json->{$hr->{title}} = $v;
		}
	}

	$self->render(json => $json);
}

sub add_routes {
	my ($self, $routes_base) = @_;

	$routes_base->get('/')->to(action => 'index');

	my $package = ref($self);

	# Add a method called "simple_$key" for each simple settings group
	foreach my $key (keys %$simple_queries) {
		no strict 'refs';
		my $subname = "simple_$key";
		*{"${package}::${subname}"} = sub { shift->_simple($key); };
		$routes_base->get("/$key")->to(controller => 'settings', action => $subname);
	}
}

# ---------------------------------------------------------------------------
# URL: /settings
# Return a list of the available (simple) settings groups
# ---------------------------------------------------------------------------

sub index {
	my ($self) = @_;

	my $json = [];
	push($json, $_) for (keys %$simple_queries);

	$self->render(json => $json);
}

sub mode {
	my $self = shift;

	$self->_simple('mode');
}

1;
