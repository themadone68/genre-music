package GenreMusicDB::Entity;

use GenreMusicDB::Base;

sub new
	{
	my $class=shift;
	my $self=bless {},$class;
	$self->{"id"}=shift;
	$self->{"name"}=shift;
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
	if(!defined($self->{"tags"}))
		{
		$self->tags();
		}
	log_error($tag." ".$self->{"tags"}->{lc($tag)});
	return defined($self->{"tags"}->{lc($tag)});
	}

sub id
	{
	my $self=shift;
	return $self->{"id"};
	}

sub name
	{
	my $self=shift;
	return $self->{"name"};
	}

sub description
	{
	my $self=shift;
	return $self->{"description"};
	}

1;
