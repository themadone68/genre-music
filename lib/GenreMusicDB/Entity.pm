package GenreMusicDB::Entity;

use GenreMusicDB::Base;
use GenreMusicDB::Object;
use GenreMusicDB::User;
use Date::Format qw(time2str);

our @ISA = qw(GenreMusicDB::Object);

sub new
	{
	my $class=shift;
	my $self=$class->SUPER::new(shift,shift);
	$self->{"description"}=shift;
	$self->{"addedby"}=shift;
	$self->{"added"}=shift;
	$self->{"moderatedby"}=shift;
	$self->{"moderated"}=shift;
	if(ref($self->{"addedby"}) ne "GenreMusicDB::User")
		{
		$self->{"addedby"}=GenreMusicDB::User->get($self->{"addedby"});
		}
	if(ref($self->{"moderatedby"}) ne "GenreMusicDB::User")
		{
		$self->{"moderatedby"}=GenreMusicDB::User->get($self->{"moderatedby"});
		}
	
	return $self;
	}

sub has_tag
	{
	my $self=shift;
	my $tag=shift;
	if(ref($tag) eq "GenreMusicDB::Tag")
		{
		$tag=$tag->name;
		}
	if(!defined($self->{"_tags"}))
		{
		$self->tags();
		}
	return defined($self->{"_tags"}->{lc($tag)});
	}

sub formatted_added
	{
	my $self=shift;
	return time2str("%Y/%m/%d",$self->added);
	}

sub type
	{
	my $self=shift;
	my $type=ref($self);
	$type =~ s/^.*::([^:]+)/$1/;
	return $type;
	}

1;
