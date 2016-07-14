#!/usr/bin/perl -Tw

use strict;
use warnings;

use Test::More tests => 9;

use_ok('GenreMusicDB::Album' ) || print "Bail out!\n";
use_ok('GenreMusicDB::Artist' ) || print "Bail out!\n";
use_ok('GenreMusicDB::Base' ) || print "Bail out!\n";
use_ok('GenreMusicDB::Entity' ) || print "Bail out!\n";
use_ok('GenreMusicDB::Role' ) || print "Bail out!\n";
use_ok('GenreMusicDB::Song' ) || print "Bail out!\n";
use_ok('GenreMusicDB::Tag' ) || print "Bail out!\n";
use_ok('GenreMusicDB::User' ) || print "Bail out!\n";
use_ok('GenreMusicDB::Object' ) || print "Bail out!\n";
