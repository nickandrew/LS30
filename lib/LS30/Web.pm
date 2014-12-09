#!/usr/bin/perl
#   Copyright (C) 2010-2014, Nick Andrew <nick@nick-andrew.net>
#   Licensed under the terms of the GNU General Public License, Version 3

package LS30::Web;

use Mojo::Base 'Mojolicious';

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
  $settings->get('/general')->to(action => 'general');
  $settings->get('/mode')->to(action => 'mode');

  my $devices = $r->get('/devices')->to(controller => 'devices', action => 'list');
}

1;
