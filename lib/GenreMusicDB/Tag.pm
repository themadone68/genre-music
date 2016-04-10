package GenreMusicDB::Tag;

use strict;
use GenreMusicDB::Base;

sub new
	{
	my $this=shift;
	my $class=ref($this) || $this;
	my $self=bless {},$class;
	$self->{"name"}=shift;
	return $self;
	}

sub name
	{
	my $self=shift;
	return $self->{"name"};
	}

sub all
	{
	my $self=shift;
	my ($sth,$row);
	my $dbh=open_database();
	my %tags;
	
	foreach my $tag ("Science Fiction","Horror","Fantasy")
		{
		$tags{lc($tag)}=GenreMusicDB::Tag->new($tag);
		}
	$sth=$dbh->prepare("SELECT tag FROM song_tags GROUP BY lower(tag)");
	if(($sth)&&($sth->execute))
		{
		while($row=$sth->fetch)
			{
			$tags{lc($row->[0])}=GenreMusicDB::Tag->new($row->[0]);
			}
		$sth->finish;
		}
	$sth=$dbh->prepare("SELECT tag FROM album_tags GROUP BY lower(tag)");
	if(($sth)&&($sth->execute))
		{
		while($row=$sth->fetch)
			{
			$tags{lc($row->[0])}=GenreMusicDB::Tag->new($row->[0]);
			}
		$sth->finish;
		}
	$sth=$dbh->prepare("SELECT tag FROM artist_tags GROUP BY lower(tag)");
	if(($sth)&&($sth->execute))
		{
		while($row=$sth->fetch)
			{
			$tags{lc($row->[0])}=GenreMusicDB::Tag->new($row->[0]);
			}
		$sth->finish;
		}
	return values %tags;
	}

sub handle
	{
	my $self=shift;
	my $env=shift;
	if($env->{"REQUEST_METHOD"} ne "POST")
		{
		if($env->{"PATH_INFO"} =~ m%^/tags/(index\.(html|json))?$%)
			{
			my $format=$2;
			my @tags=GenreMusicDB::Tag->all();
	
			return load_template($env,200,$format,"tag_index","List of Tags",
				{mainmenu => build_mainmenu($env),tags => \@tags});
			}
		elsif($env->{"PATH_INFO"} =~ m%^/tags/new.html?$%)
			{
			return error404($env);
			}
		elsif($env->{"PATH_INFO"} =~ m%^/tags/(.*?)(\.html)?$%)
			{
			my $title=$1;
			my $tag=GenreMusicDB::Tag->new($title);
			my ($sth,$row);
			my $dbh=open_database();
			my @entities;

			$sth=$dbh->prepare("SELECT * FROM songs WHERE songid IN (SELECT songid FROM song_tags WHERE tag LIKE ".$dbh->quote($title).")");
			if(($sth)&&($sth->execute))
				{
				while($row=$sth->fetch)
					{
					push @entities,GenreMusicDB::Song->new(@{$row});
					}
				$sth->finish;
				}
			$sth=$dbh->prepare("SELECT * FROM artists WHERE artistid IN (SELECT artistid FROM artist_tags WHERE tag LIKE ".$dbh->quote($title).")");
			if(($sth)&&($sth->execute))
				{
				while($row=$sth->fetch)
					{
					push @entities,GenreMusicDB::Artist->new(@{$row});
					}
				$sth->finish;
				}
			$sth=$dbh->prepare("SELECT * FROM albums WHERE albumid IN (albumid FROM album_tags WHERE tag LIKE ".$dbh->quote($title).")");
			if(($sth)&&($sth->execute))
				{
				while($row=$sth->fetch)
					{
					push @entities,GenreMusicDB::Album->new(@{$row});
					}
				$sth->finish;
				}
			
			if($#entities!=-1)
				{
				return load_template($env,200,"html","tag",$tag->name,
					{mainmenu => build_mainmenu($env),tag => $tag,entities => \@entities});
				}
			else
				{
				return error404($env);
				}
			}
		else
			{
			return error500($env);
			}
		}
	else
		{
		return error500($env);
		}
	}

sub url
	{
	my $self=shift;
	return "${sitepath}tags/".cgiencode($self->{"name"}).".html";
	}

1;
