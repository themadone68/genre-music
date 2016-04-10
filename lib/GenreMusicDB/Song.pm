package GenreMusicDB::Song;

use strict;
use GenreMusicDB::Base;
use GenreMusicDB::Entity;
use GenreMusicDB::Tag;
use GenreMusicDB::Album;
use GenreMusicDB::Artist;
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
		if($env->{"PATH_INFO"} =~ m%^/songs/(index\.(html|json))?$%)
			{
			my $format=$2;
			my @songs=GenreMusicDB::Song->all();
	
			return load_template($env,200,$format,"song_index","List of Songs",
				{mainmenu => build_mainmenu($env),songs => \@songs});
			}
		elsif($env->{"PATH_INFO"} =~ m%^/songs/new.html?$%)
			{
			if($env->{"REMOTE_USER"})
				{
				my @alltags;
				my @allalbums;
				my @allartists;
				
				@alltags=sort {lc($a->name) cmp lc($b->name)} GenreMusicDB::Tag->all();
				@allalbums=sort {lc($a->name) cmp lc($b->name)} GenreMusicDB::Album->all();
				@allartists=sort {lc($a->name) cmp lc($b->name)} GenreMusicDB::Album->all();
				return load_template($env,200,"html","new_song","Add a Song",
					{mainmenu => build_mainmenu($env),tags => \@alltags,albums => \@allalbums,artists => \@allartists,jquery=> 1,javascript=>"<script type=\"text/javascript\" src=\"".$sitepath."combomultibox.js\"></script>"});
				}
			else
				{
				return error401($env);
				}
			}
		elsif($env->{"PATH_INFO"} =~ m%^/songs/(.*?)(\.html)?$%)
			{
			my $song;
			my $title=$1;
			my ($sth,$row);
			my $dbh=open_database();
			$sth=$dbh->prepare("SELECT * FROM songs WHERE name LIKE ".$dbh->quote($title));
			if(($sth)&&($sth->execute))
				{
				if($row=$sth->fetch)
					{
					$song=GenreMusicDB::Song->new(@{$row});
					}
				$sth->finish;
				}
			if($song)
				{
				my $req = Plack::Request->new($env);
				my $query=$req->parameters;
				if(($query->{"edit"})&&($env->{"REMOTE_USER"}))
					{
					my @alltags;
					my @allalbums;
					my @allartists;
				
					@alltags=sort {lc($a->name) cmp lc($b->name)} GenreMusicDB::Tag->all();
					@allalbums=sort {lc($a->name) cmp lc($b->name)} GenreMusicDB::Album->all();
					@allartists=sort {lc($a->name) cmp lc($b->name)} GenreMusicDB::Album->all();
					return load_template($env,200,"html","edit_song","Edit ".$song->{"name"},
						{mainmenu => build_mainmenu($env),song => $song,tags => \@alltags,albums => \@allalbums,jquery=> 1,javascript=>"<script type=\"text/javascript\" src=\"".$sitepath."combomultibox.js\"></script>"});
					}
				elsif($query->{"edit"})
					{
					return error401($env);
					}
				else
					{
					return load_template($env,200,"html","song",$song->{"name"},
						{mainmenu => build_mainmenu($env),song => $song});
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
		if($query->{"delete"})
			{
			}
		else
			{
			my $song;
			if($query->{"songid"})
				{
				my ($sth,$row);
				$sth=$dbh->prepare("SELECT * FROM songs WHERE songid=".$dbh->quote($query->{"songid"}));
				if(($sth)&&($sth->execute))
					{
					if($row=$sth->fetch)
						{
						$song=GenreMusicDB::Song->new(@{$row});
						}
					$sth->finish;
					}
				}
			else
				{
				$song=GenreMusicDB::Song->new();
				}
			if(!$song)
				{
				return error500($env);
				}
			else
				{
				my $ok=$dbh->do("BEGIN");
				if($song->id)
					{
					$ok=$dbh->do("UPDATE songs SET ".join(",",map $_."=".$dbh->quote($query->{$_}),
						("name","description"))." WHERE songid=".$dbh->quote($query->{"songid"})) if($ok);
					}
				else
					{
					$ok=$dbh->do("INSERT INTO songs VALUES (".join(",",map $dbh->quote($_),
						(undef,$query->{"name"},$query->{"description"},$env->{"REMOTE_USER"},time,"",0)).")") if($ok);
					$song=GenreMusicDB::Song->new($dbh->func('last_insert_rowid'),$query->{"name"},$query->{"description"},$env->{"REMOTE_USER"},time,"",0);
					}
				my %tags;
				foreach my $tag (@{$song->tags})
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
					$ok=$dbh->do("INSERT INTO song_tags VALUES (".join(",",map $dbh->quote($_),
						($song->id,$tag,$env->{"REMOTE_USER"},time)).")") if($ok);
					}
				foreach my $tag (keys %tags)
					{
					if($tags{lc($tag)}==0)
						{
						$ok=$dbh->do("DELETE FROM song_tags WHERE songid=".$dbh->quote($song->id)." AND tag LIKE ".$dbh->quote($tag)) if($ok);
						}
					}
				my %albums;
				foreach my $albumid ($query->get_all("albums"))
					{
					my $album;
					if($albumid =~ /^albumid:(\d+)/)
						{
						$album=GenreMusicDB::Album->get($1);
						}
					else
						{
						$album=GenreMusicDB::Album->create({name => $albumid,addedby => $env->{"REMOTE_USER"}}) if($ok);
						if(!$album)
							{
							$ok=0;
							}
						}
					next if(!$album);
					$albums{$album->id}=1;
					if($song->belongs_to_album($album))
						{
						next;
						}
					$ok=$dbh->do("INSERT INTO album_songs VALUES (".join(",",map $dbh->quote($_),
						($album->id,$song->id)).")") if($ok);
					}
				foreach my $album (@{$song->albums})
					{
					next if(defined($albums{$album->id}));
					$ok=$dbh->do("DELETE FROM album_songs WHERE songid=".$dbh->quote($song->id)." AND albumid=".$dbh->quote($album->id)) if($ok);
					}
				my %artists;
				foreach my $key (keys %{$query})
					{
					if($key =~ /^artist_name-(\d+)/)
						{
						my $id=$1;
						my $artist;
						if($query->get("artist_id-$id"))
							{
							$artist=GenreMusicDB::Artist->get($query->get("artist_id-$id"));
							if(lc($artist->name) ne lc($query->get("artist_name-$id")))
								{
								$artist=undef;
								if($query->get("artist_name-$id") ne "")
									{
									$artist=GenreMusicDB::Artist->create({name => $query->get("artist_name-$id"),addedby => $env->{"REMOTE_USER"}}) if($ok);
									if(!$artist)
										{
										$ok=0;
										}
									}
								}
							}
						elsif($query->get("artist_name-$id") ne "")
							{
							$artist=GenreMusicDB::Artist->create({name => $query->get("artist_name-$id"),addedby => $env->{"REMOTE_USER"}}) if($ok);
							if(!$artist)
								{
								$ok=0;
								}
							}
						next if(!$artist);
						$artists{$artist->id}=1;
						if($song->belongs_to_artist($artist))
							{
							$ok=$dbh->do("UPDATE song_contributors SET relationship=".$dbh->quote($query->get("artist_relationship-$id"))." WHERE songid=".$dbh->quote($song->id)." AND artistid=".$dbh->quote($artist->id)) if($ok);
							}
						else
							{
							$ok=$dbh->do("INSERT INTO song_contributors VALUES (".join(",",map $dbh->quote($_),
								($song->id,$artist->id,$query->get("artist_relationship-$id"))).")") if($ok);
							}
						}
					}
				foreach my $artist (@{$song->artists})
					{
					next if(defined($artists{$artist->id}));
					$ok=$dbh->do("DELETE FROM song_contributors WHERE songid=".$dbh->quote($song->id)." AND artistid=".$dbh->quote($artist->id)) if($ok);
					}
				if($ok)
					{
					$dbh->do("COMMIT");
					return [ 302, [ 'Location' => "http://".$env->{"HTTP_HOST"}.$song->url],[] ];
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
	return "${sitepath}songs/".cgiencode($self->{"name"}).".html";
	}

sub editurl
	{
	my $self=shift;
	return "${sitepath}songs/".cgiencode($self->{"name"}).".html?edit=1";
	}

sub tags
	{
	my $self=shift;
	my @tags;

	if(!defined($self->{"tags"}))
		{
		$self->{"tags"}={};
		my $dbh=open_database();
		my ($sth,$row);
		$sth=$dbh->prepare("SELECT DISTINCT tag FROM song_tags WHERE songid=".$dbh->quote($self->id)." ORDER BY lower(tag)");
		if(($sth)&&($sth->execute))
			{
			while($row=$sth->fetch)
				{
				$self->{"tags"}->{lc($row->[0])}=GenreMusicDB::Tag->new($row->[0]);
				push @tags,$self->{"tags"}->{lc($row->[0])}
				}
			$sth->finish;
			}
		}
	else
		{
		@tags=values %{$self->{"tags"}};
		}
	return \@tags;
	}

sub belongs_to_album
	{
	my $self=shift;
	my $albumid=shift;
	my $ret=0;
	
	if(ref($albumid) eq "GenreMusicDB::Album")
		{
		$albumid=$albumid->id;
		}
	
	my $dbh=open_database();
	my ($sth,$row);
	$sth=$dbh->prepare("SELECT songid FROM album_songs WHERE songid=".$dbh->quote($self->id)." AND albumid=".$dbh->quote($albumid));
	if(($sth)&&($sth->execute))
		{
		if($row=$sth->fetch)
			{
			$ret=1;
			}
		}
	return $ret;
	}

sub belongs_to_artist
	{
	my $self=shift;
	my $artistid=shift;
	my $ret=0;
	
	if(ref($artistid) eq "GenreMusicDB::Artist")
		{
		$artistid=$artistid->id;
		}
	
	my $dbh=open_database();
	my ($sth,$row);
	$sth=$dbh->prepare("SELECT songid FROM song_contributors WHERE songid=".$dbh->quote($self->id)." AND artistid=".$dbh->quote($artistid));
	if(($sth)&&($sth->execute))
		{
		if($row=$sth->fetch)
			{
			$ret=1;
			}
		}
	return $ret;
	}

sub albums
	{
	my $self=shift;
	my @albums;
	my $dbh=open_database();
	my ($sth,$row);
	$sth=$dbh->prepare("SELECT * FROM albums WHERE albumid IN (SELECT albumid FROM album_songs WHERE songid=".$dbh->quote($self->id).")");
	if(($sth)&&($sth->execute))
		{
		if($row=$sth->fetch)
			{
			push @albums,GenreMusicDB::Album->new(@{$row});
			}
		}
	return \@albums;
	}

sub has_relationship
	{
	my $self=shift;
	my $artistid=shift;
	my $relationship=shift;
	my $ret;
	
	if(ref($artistid) eq "GenreMusicDB::Artist")
		{
		$artistid=$artistid->id;
		}
	my $dbh=open_database();
	my ($sth,$row);
	$sth=$dbh->prepare("SELECT songid FROM song_contributors WHERE songid=".$dbh->quote($self->id)." AND artistid=".$dbh->quote($artistid)." AND relationship LIKE ".$dbh->quote($relationship));
	if(($sth)&&($sth->execute))
		{
		if($row=$sth->fetch)
			{
			$ret=1;
			}
		}
	return $ret;
	}

sub relationship
	{
	my $self=shift;
	my $artistid=shift;
	my $relationship=shift;
	my $ret;
	
	if(ref($artistid) eq "GenreMusicDB::Artist")
		{
		$artistid=$artistid->id;
		}
	my $dbh=open_database();
	my ($sth,$row);
	$sth=$dbh->prepare("SELECT relationship FROM song_contributors WHERE songid=".$dbh->quote($self->id)." AND artistid=".$dbh->quote($artistid));
	if(($sth)&&($sth->execute))
		{
		if($row=$sth->fetch)
			{
			$ret=$row->[0];
			}
		}
	return $ret;
	}

sub artists
	{
	my $self=shift;
	my @artists;
	my $dbh=open_database();
	my ($sth,$row);
	$sth=$dbh->prepare("SELECT * FROM artists WHERE artistid IN (SELECT artistid FROM song_contributors WHERE songid=".$dbh->quote($self->id).")");
	if(($sth)&&($sth->execute))
		{
		while($row=$sth->fetch)
			{
			push @artists,GenreMusicDB::Artist->new(@{$row});
			}
		}
	return \@artists;
	}

sub all
	{
	my $self=shift;
	my @songs;
	my ($sth,$row);
	my $dbh=open_database();
	$sth=$dbh->prepare("SELECT * FROM songs ORDER BY moderated DESC,added DESC");
	if(($sth)&&($sth->execute))
		{
		while($row=$sth->fetch)
			{
			push @songs,GenreMusicDB::Song->new(@{$row});
			}
		$sth->finish;
		}
	return @songs;
	}
1;
