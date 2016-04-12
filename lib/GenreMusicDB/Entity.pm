package GenreMusicDB::Entity;

use GenreMusicDB::Base;
use GenreMusicDB::Object;
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
1;
