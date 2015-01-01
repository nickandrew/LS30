#!/usr/bin/perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

package LS30::Web::Controller::Base;

use Mojo::Base 'Mojolicious::Controller';

use LS30Command qw();
use LS30Connection qw();
use LS30::Commander qw();
use LS30::Message qw();
use LS30::Model qw();
use LS30::Type qw();
use YAML qw();

my $config;
my $ls30c;
my $ls30cmdr;
my $ls30model;

# Bad to put it here
LS30Command::addCommands();

sub connection {
	my ($self) = @_;

	my $config_file = 'etc/ls30.yaml';

	if (!$config && -f $config_file) {
		$config = YAML::LoadFile($config_file);
	}

	if (!$config || !$config->{default} || !$config->{default}->{host}) {
		$config = {
			default => {
				name => 'Dummy',
				host => '127.0.0.1',
				port => '1681',
			},
		};
	}

	my $default = $config->{default};

	if (!$ls30c) {
		$ls30c = LS30Connection->new($default->{host} . ':' . $default->{port});
		$ls30c->connect();
		$ls30cmdr = LS30::Commander->new($ls30c, 5);
	}

	return $ls30cmdr;
}

sub model {
	my ($self) = @_;

	if (!$ls30model) {
		$ls30model = LS30::Model->new();
		$ls30model->upstream($self->connection());
	}

	return $ls30model;
}

sub sendCommand {
	my ($self, $cmd) = @_;

	my $ls30cmdr = $self->connection();
	my $response = $ls30cmdr->sendCommand($cmd);
	my $resp_obj = LS30::Message->parse($response);

	return $resp_obj;
}

1;
