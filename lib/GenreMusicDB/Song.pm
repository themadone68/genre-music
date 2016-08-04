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
				
				@alltags=sort {lc($a->name) cmp lc($b->name)} GenreMusicDB::Tag->all();
				@allalbums=sort {lc($a->name) cmp lc($b->name)} GenreMusicDB::Album->all();
				return load_template($env,200,"html","song_new","Add a Song",
					{mainmenu => build_mainmenu($env),tags => \@alltags,albums => \@allalbums,jquery=> 1,javascript=>"<script type=\"text/javascript\" src=\"".$sitepath."combomultibox.js\"></script>"});
				}
			else
				{
				return error401($env);
				}
			}
		elsif($env->{"PATH_INFO"} =~ m%^/songs/(.*?)(\.html)?$%)
			{
			my $song=GenreMusicDB::Song->get($1);
			if($song)
				{
				my $req = Plack::Request->new($env);
				my $query=$req->parameters;
				if(($query->{"edit"})&&($env->{"REMOTE_USER"}))
					{
					my @alltags;
					my @allalbums;
				
					@alltags=sort {lc($a->name) cmp lc($b->name)} GenreMusicDB::Tag->all();
					@allalbums=sort {lc($a->name) cmp lc($b->name)} GenreMusicDB::Album->all();
					return load_template($env,200,"html","song_edit","Edit ".$song->{"name"},
						{mainmenu => build_mainmenu($env),song => $song,tags => \@alltags,albums => \@allalbums,jquery=> 1,javascript=>"<script type=\"text/javascript\" src=\"".$sitepath."combomultibox.js\"></script>"});
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
						$dbh->do("UPDATE songs SET moderated=strftime('%s','now'),moderatedby=".$dbh->quote($curruser->id)." WHERE songid=".$dbh->quote($song->id));
						return [ 302, [ 'Location' => $env->{"HTTP_REFERER"},@additionalheaders],[] ];
						}
					}
				elsif($query->{"delete"})
					{
					if(!$curruser)
						{
						return error401($env);
						}
					elsif(!(($curruser==$song->addedby)||($curruser->has_role("moderator"))||($curruser->has_role("admin"))))
						{
						return error403($env);
						}
					else
						{
						return load_template($env,200,"html","song_delete","Delete ".$song->{"name"}."?",
							{mainmenu => build_mainmenu($env),song => $song});
						}
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
		my $song;

		if($env->{"PATH_INFO"} =~ m%^/songs/((new|index).html)?$%)
			{
			$song=GenreMusicDB::Song->new();
			}
		elsif($env->{"PATH_INFO"} =~ m%^/songs/(.*?)(\.html)?$%)
			{
			my $songid=$1;
			my ($sth,$row);
			$song=GenreMusicDB::Song->get($songid);
			}

		if(!$song)
			{
			return error500($env);
			}
		else
			{
			if($query->{"delete"})
				{
				if(($query->{"confirm"} eq "Yes")&&(($curruser==$song->addedby)||($curruser->has_role("moderator"))||($curruser->has_role("admin"))))
					{
					$dbh->do("DELETE FROM songs WHERE songid=".$dbh->quote($song->id));
					}
				return [ 302, [ 'Location' => "http://".$env->{"HTTP_HOST"}."${sitepath}songs/",@additionalheaders],[] ];
				}
			else
				{
				my $ok=$dbh->do("BEGIN");
				my @errors;
				if($song->id)
					{
					$ok=$dbh->do("UPDATE songs SET ".join(",",map $_."=".$dbh->quote($query->{$_}),
						("name","description"))." WHERE songid=".$dbh->quote($query->{"songid"})) if($ok);
					}
				else
					{
					$ok=$dbh->do("INSERT INTO songs VALUES (".join(",",map $dbh->quote($_),
						(undef,$query->{"name"},$query->{"description"},$env->{"REMOTE_USER"},time,(($curruser->has_role("moderator")||$curruser->has_role("admin")) ? $curruser->id : ""),(($curruser->has_role("moderator")||$curruser->has_role("admin")) ? time : 0))).")") if($ok);
					if($ok)
						{
						$song=GenreMusicDB::Song->new($dbh->func('last_insert_rowid'),$query->{"name"},$query->{"description"},$env->{"REMOTE_USER"},time,"",0);
						}
					}
				if($ok)
					{
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
								push @errors,"Cannot create album: $albumid";
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
					$ok=$dbh->do("DELETE FROM song_contributors WHERE songid=".$dbh->quote($song->id)) if($ok);
					$ok=$dbh->do("DELETE FROM song_links WHERE songid=".$dbh->quote($song->id)) if($ok);
					foreach my $key (keys %{$query})
						{
						if(($key =~ /^artist_name-(\d+)/)&&($query->param($key) ne ""))
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
											push @errors,"Cannot create artist: ".$query->get("artist_name-$id");
											}
										}
									}
								}
							elsif($query->get("artist_name-$id") ne "")
								{
								$artist=GenreMusicDB::Artist->create({name => $query->get("artist_name-$id"),addedby => $env->{"REMOTE_USER"}}) if($ok);
								if(!$artist)
									{
									push @errors,"Cannot create artist: ".$query->get("artist_name-$id");
									}
								}
							next if(!$artist);
							$ok=$dbh->do("INSERT INTO song_contributors VALUES (".join(",",map $dbh->quote($_),
								($song->id,$artist->id,$query->get("artist_relationship-$id"))).")") if($ok);
							}
						elsif(($key =~ /^link-(\d+)/)&&($query->{$key}))
							{
							my $id=$1;
							$ok=$dbh->do("INSERT INTO song_links VALUES (".join(",",map $dbh->quote($_),
								($song->id,$query->get("link-$id"))).")") if($ok);
							}
						}
					}
				else
					{
					push @errors,"Database error: ".$DBI::errstr;
					}
				if($#errors==-1)
					{
					$dbh->do("COMMIT");
					return [ 302, [ 'Location' => "http://".$env->{"HTTP_HOST"}.$song->url,@additionalheaders],[] ];
					}
				else
					{
					$dbh->do("ROLLBACK");
					my @alltags;
					my @allalbums;
				
					@alltags=sort {lc($a->name) cmp lc($b->name)} GenreMusicDB::Tag->all();
					@allalbums=sort {lc($a->name) cmp lc($b->name)} GenreMusicDB::Album->all();
					return load_template($env,200,"html","song_edit","Edit ".$song->{"name"},
						{mainmenu => build_mainmenu($env),song => $song,errors => \@errors,tags => \@alltags,albums => \@allalbums,jquery=> 1,javascript=>"<script type=\"text/javascript\" src=\"".$sitepath."combomultibox.js\"></script>"});
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

	if(!defined($self->{"_tags"}))
		{
		$self->{"_tags"}={};
		my $dbh=open_database();
		my ($sth,$row);
		$sth=$dbh->prepare("SELECT DISTINCT tag FROM song_tags WHERE songid=".$dbh->quote($self->id)." ORDER BY lower(tag)");
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
	if(!exists($self->{"_artists"}))
		{
		$self->artists();
		}
	return exists($self->{"_artists"}->{$artistid});
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
	if(!exists($self->{"_artists"}))
		{
		$self->artists();
		}
	foreach my $rel (@{$self->{"_artists"}->{$artistid}->{"relationship"}})
		{
		if($rel eq $relationship)
			{
			return 1;
			}
		}
	return 0;
	}

sub relationship
	{
	my $self=shift;
	my $artistid=shift;
	my $relationship;
	
	if(ref($artistid) eq "GenreMusicDB::Artist")
		{
		$artistid=$artistid->id;
		}
	if(!exists $self->{"_artists"})
		{
		$self->artists();
		}
	return \@{$self->{"_artists"}->{$artistid}->{"relationship"}};
	}

sub artists
	{
	my $self=shift;
	my @artists;
	
	if(!exists($self->{"_artists"}))
		{
		$self->{"_artists"}={};
		$self->{"_relationships"}={};
		my $dbh=open_database();
		my ($sth,$row);
		$sth=$dbh->prepare("SELECT artists.*,song_contributors.relationship FROM artists JOIN song_contributors ON song_contributors.artistid=artists.artistid WHERE song_contributors.songid=".$dbh->quote($self->id));
		if(($sth)&&($sth->execute))
			{
			while($row=$sth->fetch)
				{
				if(!exists($self->{"_artists"}->{$row->[0]}))
					{
					$self->{"_artists"}->{$row->[0]}={
						"artist" => GenreMusicDB::Artist->new(@{$row}),
						"relationship" => [$row->[7]]
						};
					}
				else
					{
					push @{$self->{"_artists"}->{$row->[0]}->{"relationship"}},$row->[7];
					}
				if(!exists($self->{"_relationships"}->{$row->[7]}))
					{
					$#{$self->{"_relationships"}->{$row->[7]}}=-1;
					}
				push @{$self->{"_relationships"}->{$row->[7]}},$self->{"_artists"}->{$row->[0]}->{"artist"};
				}
			$sth->finish;
			}
		}
	@artists=map $self->{"_artists"}->{$_}->{"artist"},keys %{$self->{"_artists"}};
	return \@artists;
	}

sub all
	{
	my $self=shift;
	my $filter=shift;
	my @songs;
	my ($sth,$row);
	my $dbh=open_database();
	$sth=$dbh->prepare("SELECT * FROM songs $filter");
	if(($sth)&&($sth->execute))
		{
		while($row=$sth->fetch)
			{
			push @songs,GenreMusicDB::Song->new(@{$row});
			}
		$sth->finish;
		}
	return sort {$b->moderated <=> $a->moderated or $b->added <=> $a->added} @songs;
	}

sub get
	{
	my $self=shift;
	my $title=shift;
	my ($sth,$row);
	my $song;
	my $dbh=open_database();
	$sth=$dbh->prepare("SELECT * FROM songs WHERE name LIKE ".$dbh->quote($title)." OR songid=".$dbh->quote($title));
	if(($sth)&&($sth->execute))
		{
		if($row=$sth->fetch)
			{
			$song=GenreMusicDB::Song->new(@{$row});
			}
		$sth->finish;
		}
	return $song;
	}

sub links
	{
	my $self=shift;
	my @links;
	
	if(!exists($self->{"_links"}))
		{
		$#{$self->{"_links"}}=-1;
		my $dbh=open_database();
		my ($sth,$row);
		$sth=$dbh->prepare("SELECT * FROM song_links WHERE song_links.songid=".$dbh->quote($self->id));
		if(($sth)&&($sth->execute))
			{
			while($row=$sth->fetch)
				{
				push @{$self->{"_links"}},$row->[1];
				}
			$sth->finish;
			}
		}
	return $self->{"_links"};
	}

1;
