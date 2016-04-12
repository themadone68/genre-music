package GenreMusicDB::Entity;

use GenreMusicDB::Base;
use GenreMusicDB::Object;

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
1;
