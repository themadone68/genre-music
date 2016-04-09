package GenreMusicDB::Song;

use strict;
use GenreMusicDB::Base;
use GenreMusicDB::Entity;
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
		if($env->{"PATH_INFO"} =~ m%^/songs/(index\.html)?$%)
			{
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
	
			return load_template($env,200,"song_index","List of Songs",
				{mainmenu => build_mainmenu($env),songs => \@songs});
			}
		elsif($env->{"PATH_INFO"} =~ m%^/songs/new.html?$%)
			{
			return load_template($env,200,"new_song","Add a Song",
				{mainmenu => build_mainmenu($env)});
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
				if($query->{"edit"})
					{
					return load_template($env,200,"edit_song","Edit ".$song->{"name"},
						{mainmenu => build_mainmenu($env),song => $song});
					}
				else
					{
					return load_template($env,200,"song",$song->{"name"},
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
				if($song->{"id"})
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
					$tags{lc($tag)}=1;
					next if(defined($tags{lc($tag)}));
					$ok=$dbh->do("INSERT INTO song_tags VALUES (".join(",",map $dbh->quote($_),
						($song->{"id"},$tag,$env->{"REMOTE_USER"},time)).")") if($ok);
					}
				foreach my $tag (keys %tags)
					{
					if($tags{lc($tag)}==0)
						{
						$ok=$dbh->do("DELETE FROM song_tags WHERE songid=".$dbh->quote($song->{"id"})." AND tag LIKE ".$dbh->quote($tag)) if($ok);
						}
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
	
	my $dbh=open_database();
	my ($sth,$row);
	$sth=$dbh->prepare("SELECT DISTINCT tag FROM song_tags WHERE songid=".$dbh->quote($self->{"id"})." ORDER BY lower(tag)");
	if(($sth)&&($sth->execute))
		{
		while($row=$sth->fetch)
			{
			push @tags,$row->[0];
			}
		$sth->finish;
		}
	return \@tags;
	}

1;
