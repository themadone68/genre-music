package GenreMusicDB::Object;

use strict;
use GenreMusicDB::Base;
require Tie::Hash;
our @ISA = qw(Tie::Hash);
use vars qw ( $AUTOLOAD );
use overload '==' => \&op_equal,fallback => 1;

sub new
	{
	my $class=shift;
	my $self=bless {},$class;
	tie %{$self},$class;
	$self->{"id"}=shift;
	$self->{"name"}=shift;
	return $self;
	}

sub TIEHASH
	{
	my $self=shift;
	my $obj={};
	return bless $obj,$self;
	}

sub AUTOLOAD
	{
	my $self=shift;
	my $type=ref($self);
	our $AUTOLOAD;
	my $var=$AUTOLOAD;

	if($type eq "")
		{
		my ($a,$b,$c)=caller(0);
		die "$self is not an object: $b line $c";
		}
	$var =~ s/.*://;
	my ($parentpkg,$func,$line);
	my $caller=0;
	($parentpkg,undef,$line)=caller($caller);
	(undef,undef,undef,$func)=caller($caller+1);
	while($func =~ /::AUTOLOAD$/)
		{
		($parentpkg,undef,$line)=caller(++$caller);
		(undef,undef,undef,$func)=caller($caller+1);
		}
#	print STDERR "[$line] $parentpkg->$func: $var(",ref($self),",...)\n";
	
	if($self->can($var))
		{
		return $self->$var(@_);
		}
	elsif($#_==-1)
		{
		return $self->{$var};
		}
	else
		{
		return $self->{$var}=$_[0];
		}
	}

sub FETCH
	{
	my $self=shift;
	my $var=shift;
	my ($parentpkg,$func,$line);
	my $caller=0;
	($parentpkg,undef,$line)=caller($caller);
	(undef,undef,undef,$func)=caller($caller+1);
	while($func =~ /::AUTOLOAD$/)
		{
		($parentpkg,undef,$line)=caller(++$caller);
		(undef,undef,undef,$func)=caller($caller+1);
		}
	
	if($self->can($var))
		{
		return $self->$var;
		}
	else
		{
#		print STDERR "[$line] $parentpkg->$func: FETCH(",ref($self),",$var)\n";
		return $self->{$var};
		}
	}

sub STORE
	{
	my $self=shift;
	my $var=shift;
	my $value=shift;
	my ($parentpkg,$func,$line);
	($parentpkg,undef,$line)=caller(0);
	my $caller=1;
	(undef,undef,undef,$func)=caller($caller);
	while($func =~ /::AUTOLOAD$/)
		{
		($parentpkg,undef,$line)=caller(++$caller);
		(undef,undef,undef,$func)=caller($caller+1);
		}
	if(($self->can($var))&&($func ne ref($self)."::new"))
		{
		return $self->$var($value);
		}
	else
		{
#		print STDERR "[$line] $parentpkg->$func: STORE(",ref($self),",$var,$value)\n";
		$self->{$var}=$value;
		}
	return $self;
	}

sub DESTROY
	{
	}

sub EXISTS
	{
	my $self=shift;
	my $var;
	return exists $self->{$var};
	}

sub FIRSTKEY { my $a = scalar keys %{$_[0]}; each %{$_[0]} }
sub NEXTKEY  { each %{$_[0]} }

sub link
	{
	my $self=shift;
	return "<a href=\"".htmlencode($self->url)."\">".$self->name."</a>";
	}

sub editlink
	{
	my $self=shift;
	return "<a href=\"".htmlencode($self->editurl)."\">".$self->name."</a>";
	}

sub op_equal
	{
	my $self=shift;
	my $other=shift;
	
	if((ref($self) eq ref($other))&&($self->id eq $other->id))
		{
		return 1;
		}
	else
		{
		return 0;
		}
	}

1;
