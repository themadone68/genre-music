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

1;
