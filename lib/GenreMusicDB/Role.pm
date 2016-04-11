package GenreMusicDB::Role;

use strict;
use GenreMusicDB::Base;
use GenreMusicDB::User;

sub new
	{
	my $class=shift;
	my $self=bless {},$class;
	$self->{"id"}=shift;
	$self->{"name"}=shift;
	
	return $self;
	}

sub id
	{
	my $self=shift;
	return $self->{"id"};
	}

sub handle
	{
	my $self=shift;
	my $env=shift;
	my $adminrole=GenreMusicDB::Role->get("admin");

	if($env->{"REQUEST_METHOD"} ne "POST")
		{
		if($env->{"PATH_INFO"} =~ m%^/roles/(index\.(html|json))?$%)
			{
			my $format=$2;
			my @roles=GenreMusicDB::Role->all();
	
			return load_template($env,200,$format,"role_index","List of Roles",
				{mainmenu => build_mainmenu($env),roles => \@roles});
			}
		elsif($env->{"PATH_INFO"} =~ m%^/roles/new.html?$%)
			{
			if($env->{"REMOTE_USER"})
				{
				if(($adminrole)&&($adminrole->has_member($env->{"REMOTE_USER"})))
					{
					my @allusers;
				
					@allusers=GenreMusicDB::User->all();
					return load_template($env,200,"html","new_role","Add a Role",
						{mainmenu => build_mainmenu($env),users => \@allusers,jquery=> 1,javascript=>"<script type=\"text/javascript\" src=\"".$sitepath."combomultibox.js\"></script>"});
					}
				else
					{
					return error403($env);
					}
				}
			else
				{
				return error401($env);
				}
			}
		elsif($env->{"PATH_INFO"} =~ m%^/roles/(.*?)(\.html)?$%)
			{
			my $role;
			my $title=$1;
			my ($sth,$row);
			my $dbh=open_database();
			$sth=$dbh->prepare("SELECT * FROM roles WHERE name LIKE ".$dbh->quote($title));
			if(($sth)&&($sth->execute))
				{
				if($row=$sth->fetch)
					{
					$role=GenreMusicDB::Role->new(@{$row});
					}
				$sth->finish;
				}
			if($role)
				{
				my $req = Plack::Request->new($env);
				my $query=$req->parameters;
				
				if(($query->{"edit"})&&($env->{"REMOTE_USER"}))
					{
					if(($adminrole)&&($adminrole->has_member($env->{"REMOTE_USER"})))
						{
						my @allusers;
				
						@allusers=GenreMusicDB::User->all();
						return load_template($env,200,"html","edit_role","Edit ".$role->{"name"},
							{mainmenu => build_mainmenu($env),role => $role,users => \@allusers,jquery=> 1,javascript=>"<script type=\"text/javascript\" src=\"".$sitepath."combomultibox.js\"></script>"});
						}
					else
						{
						return error403($env);
						}
					}
				elsif($query->{"edit"})
					{
					return error401($env);
					}
				else
					{
					return load_template($env,200,"html","role",$role->{"name"},
						{mainmenu => build_mainmenu($env),role => $role});
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
	elsif($env->{"REMOTE_USER"} eq "")
		{
		return error401($env);
		}
	elsif((!$adminrole)||(!$adminrole->has_member($env->{"REMOTE_USER"})))
		{
		return error403($env);
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
			my $role;
			if($query->{"roleid"})
				{
				my ($sth,$row);
				$sth=$dbh->prepare("SELECT * FROM roles WHERE roleid=".$dbh->quote($query->{"roleid"}));
				if(($sth)&&($sth->execute))
					{
					if($row=$sth->fetch)
						{
						$role=GenreMusicDB::Role->new(@{$row});
						}
					$sth->finish;
					}
				}
			else
				{
				$role=GenreMusicDB::Role->new();
				}
			if(!$role)
				{
				return error500($env);
				}
			else
				{
				my $ok=$dbh->do("BEGIN");
				if($role->{"id"})
					{
					$ok=$dbh->do("UPDATE roles SET ".join(",",map $_."=".$dbh->quote($query->{$_}),
						("name"))." WHERE roleid=".$dbh->quote($query->{"roleid"})) if($ok);
					}
				else
					{
					my $newid=lc($query->{"name"});
					$newid =~ s/[^a-z0-9]+/_/g;
					$ok=$dbh->do("INSERT INTO roles VALUES (".join(",",map $dbh->quote($_),
						($newid,$query->{"name"})).")") if($ok);
					$role=GenreMusicDB::Role->new($newid,$query->{"name"});
					}
				$ok=$dbh->do("DELETE FROM role_members WHERE roleid=".$dbh->quote($role->id)) if($ok);
				foreach my $member ($query->get_all("members"))
					{
					$ok=$dbh->do("INSERT INTO role_members VALUES (".join(",",map $dbh->quote($_),
						($role->id,$member)).")") if($ok);
					}
				if($ok)
					{
					$dbh->do("COMMIT");
					return [ 302, [ 'Location' => "http://".$env->{"HTTP_HOST"}.$role->url],[] ];
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
	return "${sitepath}roles/".cgiencode($self->{"name"}).".html";
	}

sub editurl
	{
	my $self=shift;
	return "${sitepath}roles/".cgiencode($self->{"name"}).".html?edit=1";
	}

sub all
	{
	my $self=shift;
	my ($sth,$row);
	my @roles;
	my $dbh=open_database();
	$sth=$dbh->prepare("SELECT * FROM roles ORDER BY lower(name)");
	if(($sth)&&($sth->execute))
		{
		while($row=$sth->fetch)
			{
			push @roles,GenreMusicDB::Role->new(@{$row});
			}
		$sth->finish;
		}
	return @roles;
	}

sub members
	{
	my $self=shift;
	my @members;
	my ($sth,$row);
	my $dbh=open_database();
	if(!defined($self->{"members"}))
		{
		$self->{"members"}={};
		$sth=$dbh->prepare("SELECT userid,name,email FROM users WHERE userid IN (SELECT userid FROM role_members WHERE roleid=".$dbh->quote($self->id).")");
		if(($sth)&&($sth->execute))
			{
			while($row=$sth->fetch)
				{
				$self->{"members"}->{lc($row->[0])}=GenreMusicDB::User->new(@{$row});
				push @members,$self->{"members"}->{lc($row->[0])};
				}
			$sth->finish;
			}
		}
	else
		{
		@members=values %{$self->{"members"}};
		}
	
	return \@members;
	}

sub has_member
	{
	my $self=shift;
	my $userid=shift;
	
	if(ref($userid) eq "GenreMusicDB::User")
		{
		$userid=$userid->id;
		}
	if(!defined($self->{"members"}))
		{
		$self->members();
		}
	return defined($self->{"members"}->{$userid});
	}

sub get
	{
	my $self=shift;
	my $id=shift;
	my ($sth,$row);
	my $ret;
	my $dbh=open_database();
	$sth=$dbh->prepare("SELECT * FROM roles WHERE roleid=".$dbh->quote($id));
	if(($sth)&&($sth->execute))
		{
		while($row=$sth->fetch)
			{
			$ret=GenreMusicDB::Role->new(@{$row});
			}
		$sth->finish;
		}
	return $ret;
	}

1;
