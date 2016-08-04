package GenreMusicDB::Album;

use strict;
use GenreMusicDB::Base;
use GenreMusicDB::Entity;
use GenreMusicDB::Tag;
use Data::Dumper;

our @ISA = qw(GenreMusicDB::Entity);

sub new
	{
	my $this=shift;
	my $class=ref($this) || $this;
	my $self=$class->SUPER::new(@_);
	
	return $self;
	}

sub handle
	{
	my $self=shift;
	my $env=shift;
	if($env->{"REQUEST_METHOD"} ne "POST")
		{
		if($env->{"PATH_INFO"} =~ m%^/albums(/(index\.(html|json))?)?$%)
			{
			my $format=$3;
			my @albums=GenreMusicDB::Album->all();
	
			return load_template($env,200,$format,"album_index","List of Albums",
				{mainmenu => build_mainmenu($env),albums => \@albums});
			}
		elsif($env->{"PATH_INFO"} =~ m%^/albums/new.html?$%)
			{
			if($env->{"REMOTE_USER"})
				{
				my @alltags;
				
				@alltags=GenreMusicDB::Tag->all();
				return load_template($env,200,"html","album_new","Add a Album",
					{mainmenu => build_mainmenu($env),tags => \@alltags,jquery=> 1,javascript=>"<script type=\"text/javascript\" src=\"".$sitepath."combomultibox.js\"></script>"});
				}
			else
				{
				return error401($env);
				}
			}
		elsif($env->{"PATH_INFO"} =~ m%^/albums/(.*?)(\.html)?$%)
			{
			my $album;
			my $title=$1;
			my ($sth,$row);
			my $dbh=open_database();
			$sth=$dbh->prepare("SELECT * FROM albums WHERE name LIKE ".$dbh->quote($title));
			if(($sth)&&($sth->execute))
				{
				if($row=$sth->fetch)
					{
					$album=GenreMusicDB::Album->new(@{$row});
					}
				$sth->finish;
				}
			if($album)
				{
				my $req = Plack::Request->new($env);
				my $query=$req->parameters;
				
				if(($query->{"edit"})&&($env->{"REMOTE_USER"}))
					{
					my @alltags;
				
					@alltags=GenreMusicDB::Tag->all();
					return load_template($env,200,"html","album_edit","Edit ".$album->{"name"},
						{mainmenu => build_mainmenu($env),album => $album,tags => \@alltags,jquery=> 1,javascript=>"<script type=\"text/javascript\" src=\"".$sitepath."combomultibox.js\"></script>"});
					}
				elsif($query->{"edit"})
					{
					return error401($env);
					}
				elsif($query->{"moderate"})
					{
					if(!$curruser)
						{
						return error401($env);
						}
					elsif(!($curruser->has_role("moderator")||$curruser->has_role("admin")))
						{
						return error403($env);
						}
					else
						{
						my $dbh=open_database();
						$dbh->do("UPDATE albums SET moderated=strftime('%s','now'),moderatedby=".$dbh->quote($curruser->id)." WHERE albumid=".$dbh->quote($album->id));
						return [ 302, [ 'Location' => $env->{"HTTP_REFERER"},@additionalheaders],[] ];
						}
					}
				elsif($query->{"delete"})
					{
					if(!$curruser)
						{
						return error401($env);
						}
					elsif(!(($curruser==$album->addedby)||($curruser->has_role("moderator"))||($curruser->has_role("admin"))))
						{
						return error403($env);
						}
					else
						{
						return load_template($env,200,"html","album_delete","Delete ".$album->{"name"}."?",
							{mainmenu => build_mainmenu($env),album => $album});
						}
					}
				else
					{
					return load_template($env,200,"html","album",$album->{"name"},
						{mainmenu => build_mainmenu($env),album => $album});
					}
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
		my $req = Plack::Request->new($env);
		my $query=$req->parameters;
		my $dbh=open_database();
		my $album;
		if($env->{"PATH_INFO"} =~ m%^/albums/((new|index).html)?$%)
			{
			$album=GenreMusicDB::Album->new();
			}
		elsif($env->{"PATH_INFO"} =~ m%^/albums/(.*?)(\.html)?$%)
			{
			my $albumid=$1;
			my ($sth,$row);
			$album=GenreMusicDB::Album->get($albumid);
			}

		if(!$album)
			{
			return error500($env);
			}
		else
			{
			if($query->{"delete"})
				{
				if(($query->{"confirm"} eq "Yes")&&(($curruser==$album->addedby)||($curruser->has_role("moderator"))||($curruser->has_role("admin"))))
					{
					$dbh->do("DELETE FROM albums WHERE albumid=".$dbh->quote($album->id));
					}
				return [ 302, [ 'Location' => "http://".$env->{"HTTP_HOST"}."${sitepath}albums/",@additionalheaders],[] ];
				}
			else
				{
				my $ok=$dbh->do("BEGIN");
				if($album->{"id"})
					{
					$ok=$dbh->do("UPDATE albums SET ".join(",",map $_."=".$dbh->quote($query->{$_}),
						("name","description"))." WHERE albumid=".$dbh->quote($query->{"albumid"})) if($ok);
					}
				else
					{
					$ok=$dbh->do("INSERT INTO albums VALUES (".join(",",map $dbh->quote($_),
						(undef,$query->{"name"},$query->{"description"},$env->{"REMOTE_USER"},time,(($curruser->has_role("moderator")||$curruser->has_role("admin")) ? $curruser->id : ""),(($curruser->has_role("moderator")||$curruser->has_role("admin")) ? time : 0))).")") if($ok);
					$album=GenreMusicDB::Album->new($dbh->func('last_insert_rowid'),$query->{"name"},$query->{"description"},$env->{"REMOTE_USER"},time,"",0);
					}
				my %tags;
				foreach my $tag (@{$album->tags})
					{
					$tags{lc($tag)}=0;
					}
				foreach my $tag ($query->get_all("tags"))
					{
					next if($tag =~ /^\s*$/);
					if(defined($tags{lc($tag)}))
						{
						$tags{lc($tag)}=1;
						next;
						}
					$tags{lc($tag)}=1;
					$ok=$dbh->do("INSERT INTO album_tags VALUES (".join(",",map $dbh->quote($_),
						($album->{"id"},$tag,$env->{"REMOTE_USER"},time)).")") if($ok);
					}
				foreach my $tag (keys %tags)
					{
					if($tags{lc($tag)}==0)
						{
						$ok=$dbh->do("DELETE FROM album_tags WHERE albumid=".$dbh->quote($album->{"id"})." AND tag LIKE ".$dbh->quote($tag)) if($ok);
						}
					}
				if($ok)
					{
					$dbh->do("COMMIT");
					return [ 302, [ 'Location' => "http://".$env->{"HTTP_HOST"}.$album->url,@additionalheaders],[] ];
					}
				else
					{
					$dbh->do("ROLLBACK");
					return error500($env);
					}
				}
			}
		}
	}

sub url
	{
	my $self=shift;
	return "${sitepath}albums/".cgiencode($self->{"name"}).".html";
	}

sub editurl
	{
	my $self=shift;
	return "${sitepath}albums/".cgiencode($self->{"name"}).".html?edit=1";
	}

sub tags
	{
	my $self=shift;
	my @tags;

	if(!defined($self->{"_tags"}))
		{
		$self->{"_tags"}={};
		my $dbh=open_database();
		my ($sth,$row);
		$sth=$dbh->prepare("SELECT DISTINCT tag FROM album_tags WHERE albumid=".$dbh->quote($self->id)." ORDER BY lower(tag)");
		if(($sth)&&($sth->execute))
			{
			while($row=$sth->fetch)
				{
				$self->{"_tags"}->{lc($row->[0])}=GenreMusicDB::Tag->new($row->[0]);
				push @tags,$self->{"_tags"}->{lc($row->[0])}
				}
			$sth->finish;
			}
		}
	else
		{
		@tags=values %{$self->{"_tags"}};
		}
	return \@tags;
	}

sub has_song
	{
	my $self=shift;
	my $songid=shift;
	my $ret=0;
	
	if(!defined($self->{"_songs"}))
		{
		$self->songs();
		}
	return(defined($self->{"_songs"}->{$songid}));
	}

sub create
	{
	my $self=shift;
	my $dbh=open_database();
	my $params=(ref($_[0]) eq "HASH" ? $_[0] : %{@_});
	my $newself;
	
	if($dbh->do("INSERT INTO albums VALUES (".join(",",map $dbh->quote($_),
		(undef,$params->{"name"},$params->{"description"},$params->{"addedby"},time,"",0)).")"))
		{
		return $self->new($dbh->func('last_insert_rowid'),$params->{"name"},$params->{"description"},$params->{"addedby"},time,"",0);
		}
	else
		{
		return undef;
		}
	}

sub all
	{
	my $self=shift;
	my $filter=shift;
	my ($sth,$row);
	my @albums;
	my $dbh=open_database();
	$sth=$dbh->prepare("SELECT * FROM albums $filter");
	if(($sth)&&($sth->execute))
		{
		while($row=$sth->fetch)
			{
			push @albums,GenreMusicDB::Album->new(@{$row});
			}
		$sth->finish;
		}
	return sort {$b->moderated <=> $a->moderated or $b->added <=> $a->added} @albums;
	}

sub get
	{
	my $self=shift;
	my $id=shift;
	my ($sth,$row);
	my $ret;
	my $dbh=open_database();
	$sth=$dbh->prepare("SELECT * FROM albums WHERE albumid=".$dbh->quote($id));
	if(($sth)&&($sth->execute))
		{
		while($row=$sth->fetch)
			{
			$ret=GenreMusicDB::Album->new(@{$row});
			}
		$sth->finish;
		}
	return $ret;
	}

sub songs
	{
	my $self=shift;
	my $dbh=open_database();
	my ($sth,$row);
	if(!defined($self->{"_songs"}))
		{
		$self->{"_songs"}={};
		$sth=$dbh->prepare("SELECT * FROM songs WHERE songid IN (SELECT songid FROM album_songs WHERE albumid=".$dbh->quote($self->id).")");
		if(($sth)&&($sth->execute))
			{
			if($row=$sth->fetch)
				{
				$self->{"_songs"}->{$row->[0]}=GenreMusicDB::Song->new(@{$row});
				}
			}
		}
	return values %{$self->{"_songs"}};
	}

1;
