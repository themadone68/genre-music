#!/usr/bin/perl -Tw

use strict;
use warnings;

use Test::More tests => 1;

ok(require './app.psgi');
