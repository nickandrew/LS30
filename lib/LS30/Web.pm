#!/usr/bin/perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

package LS30::Web;

use Mojo::Base 'Mojolicious';

use LS30::Web::Controller::Settings qw();

# This method will run once at server start
sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc"
  $self->plugin('PODRenderer');

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to('example#welcome');

  my $settings = $r->get('/settings')->to(controller => 'settings');
  my $settings_controller = LS30::Web::Controller::Settings->new();
  $settings_controller->add_routes($settings);

  my $devices = $r->get('/devices')->to(controller => 'devices');
  $devices->get('/')->to(action => 'list');
  $devices->get('/:type')->to(action => 'list_type');

  $r->get('/eventlog')->to(controller => 'EventLog', action => 'list');
}

1;
