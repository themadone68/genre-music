package GenreMusicDB::Artist;

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
		if($env->{"PATH_INFO"} =~ m%^/artists/(index\.(html|json))?$%)
			{
			my $format=$2;
			my @artists=GenreMusicDB::Artist->all();
	
			return load_template($env,200,$format,"artist_index","List of Artists",
				{mainmenu => build_mainmenu($env),artists => \@artists});
			}
		elsif($env->{"PATH_INFO"} =~ m%^/artists/new.html?$%)
			{
			if($env->{"REMOTE_USER"})
				{
				my @alltags;
					
				@alltags=GenreMusicDB::Tag->all();
				return load_template($env,200,"html","artist_new","Add a Artist",
					{mainmenu => build_mainmenu($env),tags => \@alltags,jquery=> 1,javascript=>"<script type=\"text/javascript\" src=\"".$sitepath."combomultibox.js\"></script>"});
				}
			else
				{
				return error401($env);
				}
			}
		elsif($env->{"PATH_INFO"} =~ m%^/artists/(.*?)(\.html)?$%)
			{
			my $artist;
			my $title=$1;
			my ($sth,$row);
			my $dbh=open_database();
			$sth=$dbh->prepare("SELECT * FROM artists WHERE name LIKE ".$dbh->quote($title));
			if(($sth)&&($sth->execute))
				{
				if($row=$sth->fetch)
					{
					$artist=GenreMusicDB::Artist->new(@{$row});
					}
				$sth->finish;
				}
			if($artist)
				{
				my $req = Plack::Request->new($env);
				my $query=$req->parameters;
				
				if(($query->{"edit"})&&($env->{"REMOTE_USER"}))
					{
					my @alltags;
				
					@alltags=GenreMusicDB::Tag->all(@{$artist->tags});
					return load_template($env,200,"html","artist_edit","Edit ".$artist->{"name"},
						{mainmenu => build_mainmenu($env),artist => $artist,tags => \@alltags,jquery=> 1,javascript=>"<script type=\"text/javascript\" src=\"".$sitepath."combomultibox.js\"></script>"});
					}
				elsif($query->{"edit"})
					{
					return error401($env);
					}
				else
					{
					return load_template($env,200,"html","artist",$artist->{"name"},
						{mainmenu => build_mainmenu($env),artist => $artist});
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
			my $artist;
			if($query->{"artistid"})
				{
				my ($sth,$row);
				$sth=$dbh->prepare("SELECT * FROM artists WHERE artistid=".$dbh->quote($query->{"artistid"}));
				if(($sth)&&($sth->execute))
					{
					if($row=$sth->fetch)
						{
						$artist=GenreMusicDB::Artist->new(@{$row});
						}
					$sth->finish;
					}
				}
			else
				{
				$artist=GenreMusicDB::Artist->new();
				}
			if(!$artist)
				{
				return error500($env);
				}
			else
				{
				my $ok=$dbh->do("BEGIN");
				if($artist->id)
					{
					$ok=$dbh->do("UPDATE artists SET ".join(",",map $_."=".$dbh->quote($query->{$_}),
						("name","description"))." WHERE artistid=".$dbh->quote($query->{"artistid"})) if($ok);
					}
				else
					{
					$ok=$dbh->do("INSERT INTO artists VALUES (".join(",",map $dbh->quote($_),
						(undef,$query->{"name"},$query->{"description"},$env->{"REMOTE_USER"},time,"",0)).")") if($ok);
					$artist=GenreMusicDB::Artist->new($dbh->func('last_insert_rowid'),$query->{"name"},$query->{"description"},$env->{"REMOTE_USER"},time,"",0);
					}
				my %tags;
				foreach my $tag (@{$artist->tags})
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
					$ok=$dbh->do("INSERT INTO artist_tags VALUES (".join(",",map $dbh->quote($_),
						($artist->id,$tag,$env->{"REMOTE_USER"},time)).")") if($ok);
					}
				foreach my $tag (keys %tags)
					{
					if($tags{lc($tag)}==0)
						{
						$ok=$dbh->do("DELETE FROM artist_tags WHERE artistid=".$dbh->quote($artist->id)." AND tag LIKE ".$dbh->quote($tag)) if($ok);
						}
					}
				if($ok)
					{
					$dbh->do("COMMIT");
					return [ 302, [ 'Location' => "http://".$env->{"HTTP_HOST"}.$artist->url],[] ];
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
	return "${sitepath}artists/".cgiencode($self->{"name"}).".html";
	}

sub editurl
	{
	my $self=shift;
	return "${sitepath}artists/".cgiencode($self->{"name"}).".html?edit=1";
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
		$sth=$dbh->prepare("SELECT DISTINCT tag FROM artist_tags WHERE artistid=".$dbh->quote($self->id)." ORDER BY lower(tag)");
		if(($sth)&&($sth->execute))
			{
			while($row=$sth->fetch)
				{
				$self->{"tags"}->{lc($row->[0])}=$row->[0];
				push @tags,$row->[0];
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

sub has_song
	{
	my $self=shift;
	my $songid=shift;
	my $ret=0;
	
	my $dbh=open_database();
	my ($sth,$row);
	$sth=$dbh->prepare("SELECT songid FROM song_contributors WHERE artistid=".$dbh->quote($self->id)." AND songid=".$dbh->quote($songid));
	if(($sth)&&($sth->execute))
		{
		if($row=$sth->fetch)
			{
			$ret=1;
			}
		}
	return $ret;
	}

sub create
	{
	my $self=shift;
	my $dbh=open_database();
	my $params=(ref($_[0]) eq "HASH" ? $_[0] : %{@_});
	my $newself;
	
	if($dbh->do("INSERT INTO artists VALUES (".join(",",map $dbh->quote($_),
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
	my $where=shift;
	my ($sth,$row);
	my @artists;
	my $dbh=open_database();
	$sth=$dbh->prepare("SELECT * FROM artists".($where ? " WHERE $where" : "")." ORDER BY moderated DESC,added DESC");
	if(($sth)&&($sth->execute))
		{
		while($row=$sth->fetch)
			{
			push @artists,GenreMusicDB::Artist->new(@{$row});
			}
		$sth->finish;
		}
	return @artists;
	}

sub get
	{
	my $self=shift;
	my $id=shift;
	my ($sth,$row);
	my $ret;
	my $dbh=open_database();
	$sth=$dbh->prepare("SELECT * FROM artists WHERE artistid=".$dbh->quote($id));
	if(($sth)&&($sth->execute))
		{
		while($row=$sth->fetch)
			{
			$ret=GenreMusicDB::Artist->new(@{$row});
			}
		$sth->finish;
		}
	return $ret;
	}

1;
