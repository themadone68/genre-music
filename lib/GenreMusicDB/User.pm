package GenreMusicDB::User;

use strict;
use GenreMusicDB::Base;
use GenreMusicDB::Object;
use GenreMusicDB::Role;
use MIME::Entity;

our @ISA = qw(GenreMusicDB::Object);
my @saltchars=("0".."9","a".."z","A".."Z");

sub new
	{
	my $this=shift;
	my $class=ref($this) || $this;
	my $self=$class->SUPER::new(shift,shift);
	$self->{"email"}=shift;
	$self->{"password"}=shift;
	return $self;
	}

sub handle
	{
	my $self=shift;
	my $env=shift;
	if($env->{"REQUEST_METHOD"} ne "POST")
		{
		if($env->{"PATH_INFO"} =~ m%^/users/(index\.html)?$%)
			{
			my @users=GenreMusicDB::User->all();
			return load_template($env,200,"html","user_index","List of Users",
				{mainmenu => build_mainmenu($env),users => \@users});
			}
		elsif($env->{"PATH_INFO"} =~ m%^/users/new.html$%)
			{
			if($env->{"REMOTE_USER"})
				{
				return load_template($env,200,"html","user_new","Invite a Friend",
					{mainmenu => build_mainmenu($env)});
				}
			else
				{
				return error401($env);
				}
			}
		elsif($env->{"PATH_INFO"} =~ m%^/users/(.*?)(\.html)?$%)
			{
			my $user;
			my $userid=$1;
			my ($sth,$row);
			my $dbh=open_database();
			if($userid eq "me")
				{
				$userid=$env->{"REMOTE_USER"};
				}
			$user=GenreMusicDB::User->get($userid);
			if($user)
				{
				my $req = Plack::Request->new($env);
				my $query=$req->parameters;
				if(($query->{"edit"})&&($env->{"REMOTE_USER"}))
					{
					if($user->id eq $env->{"REMOTE_USER"})
						{
						return load_template($env,200,"html","user_edit",(!$user->is_temporary ? "Edit profile" : "Finish Registration"),
							{mainmenu => build_mainmenu($env),user => $user});
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
					return load_template($env,200,"html","user",$user->name." Profile",
						{mainmenu => build_mainmenu($env),user => $user});
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
		my $user;

		if($env->{"PATH_INFO"} =~ m%^/users/((new|index).html)?$%)
			{
			$user=GenreMusicDB::User->new();
			}
		elsif($env->{"PATH_INFO"} =~ m%^/users/(.*?)(\.html)?$%)
			{
			my $userid=$1;
			my ($sth,$row);
			if($userid eq "me")
				{
				$userid=$env->{"REMOTE_USER"};
				}
			$user=GenreMusicDB::User->get($userid);
			}

		if($query->{"delete"})
			{
			}
		else
			{
			if(!$user)
				{
				log_error("No user to update?");
				return error500($env);
				}
			else
				{
				my $ok=$dbh->do("BEGIN");
				if($user->id)
					{
					my @validfields;
					my @errors;
					if($user->is_temporary)
						{
						if($query->{"userid"} =~ /^[a-zA-Z0-9_-]+$/)
							{
							push @validfields,"userid";
							}
						else
							{
							push @errors,"userid";
							}
						}
					if($query->{"email"} ne $user->email)
						{
						if($query->{"email"} =~ /^[a-zA-Z0-9._-]+\@[.a-zA-Z0-9_-]+[a-zA-Z]$/)
							{
							push @validfields,"userid";
							}
						else
							{
							push @errors,"email";
							}
						}
					if($query->{"name"} ne "")
						{
						push @validfields,"name";
						}
					else
						{
						push @errors,"name";
						}
					if($query->{"newpassword"} ne "")
						{
						if($query->{"confirm"} ne $query->{"newpassword"})
							{
							push @errors,"pwmismatch";
							}
						elsif(!$user->has_password($query->{"password"}))
							{
							push @errors,"wrongpw";
							}
						else
							{
							my $salt=$saltchars[int(rand($#saltchars+1))].$saltchars[int(rand($#saltchars+1))];
							$query->{"password"}=crypt($query->{"newpassword"},$salt);
							push @validfields,"password";
							}
						}
					
					if($#errors==-1)
						{
						$ok=$dbh->do("UPDATE users SET ".join(",",map $_."=".$dbh->quote($query->{$_}),
							@validfields)." WHERE userid=".$dbh->quote($user->id)) if($ok);
						if($query->{"password"})
							{
							my ($session)=(($env->{"HTTP_COOKIE"} || "") =~ /GenreMusicDB=([^;]+)/);
							$ok=$dbh->do("UPDATE sessions SET password=".$dbh->quote($query->{"password"})." WHERE sessionid=".$dbh->quote($session)) if($ok);
							}
						}
					else
						{
						$dbh->do("ROLLBACK");
						return load_template($env,200,"html","user_edit",(!$user->is_temporary ? "Edit profile" : "Finish Registration"),
							{mainmenu => build_mainmenu($env),user => $user,errors => \@errors});
						}

					if($ok)
						{
						$dbh->do("COMMIT");
						return [ 302, [ 'Location' => "http://".$env->{"HTTP_HOST"}.$user->url,@additionalheaders],[] ];
						}
					else
						{
						$dbh->do("ROLLBACK");
						return error500($env);
						}
					}
				else
					{
					my $newid="temp:1";
					my ($sth,$row);
					$sth=$dbh->prepare("SELECT max(substr(userid,6)+0) FROM users WHERE userid LIKE 'temp:%'");
					if(($sth)&&($sth->execute))
						{
						if($row=$sth->fetch)
							{
							if($row->[0])
								{
								$newid="temp:".($row->[0]+1);
								}
							}
						$sth->finish;
						}
					my $salt=$saltchars[int(rand($#saltchars+1))].$saltchars[int(rand($#saltchars+1))];
					my $newpassword=int(rand(100000));
					my $password=crypt($newpassword,$salt);
					$ok=$dbh->do("INSERT INTO users VALUES (".join(",",map $dbh->quote($_),
						($newid,$query->{"name"},$query->{"email"},$password,time,$curruser->id,0)).")") if($ok);
					$user=GenreMusicDB::User->new($newid,$query->{"name"},$query->{"email"},"");
					if($ok)
						{
						my $template = Template->new(
							{
							INCLUDE_PATH => $filepath,
							FILTERS =>
								{
								"htmlencode" => \&htmlencode,
								"cgiencode" => \&cgiencode,
								}
							});
	
						my ($text,$html);
						my $otheruser=GenreMusicDB::User->get($env->{"REMOTE_USER"});
						my $vars=
							{
							"sitepath" => $sitepath,
							"curruser" => $env->{"REMOTE_USER"} || "",
							"siteurl" => "http".($env->{"SERVER_PORT"}==443 ? "s" : "")."://".$env->{"HTTP_HOST"}.($env->{"SCRIPT_NAME"}|| "/"),
							"utm_medium" => "email",
							"utm_campaign" => "invite",
							"otheruser" => $otheruser,
							"password" => $newpassword,
							};
						if(($template->process("templates/text/email_invite.tmpl",$vars,\$text))&&
							($template->process("templates/html/email_invite.tmpl",$vars,\$html)))
							{
							if(open(MAIL,"|/usr/lib/sendmail -t -f postmaster\@thingsilove.org.uk"))
								{
								my $mimemail = MIME::Entity->build(Type => "multipart/alternative",
									From => "I Need To Config This <chris\@instituteofcorrection.org.uk>",
									To => $query->{"name"}." <".$query->{"email"}.">",
									Subject => "Invitation to the Genre Music Database");
								$mimemail->attach(Type => "text/plain",
									Encoding => "quoted-printable",
									Data => $text);
								$mimemail->attach(Type => "text/html",
									Encoding => "7bit",
									Data => $html);
								$mimemail->print(\*MAIL);
								close(MAIL);
								$dbh->do("COMMIT");
								return [ 302, [ 'Location' => "http://".$env->{"HTTP_HOST"}.$sitepath."invite_sent.html",@additionalheaders],[] ];
								}
							else
								{
								$dbh->do("ROLLBACK");
								return error500($env);
								}
							}
						else
							{
							log_error("Template fail");
							$dbh->do("ROLLBACK");
							return error500($env);
							}
						}
					else
						{
						log_error($DBI::errstr);
						$dbh->do("ROLLBACK");
						return error500($env);
						}
					}
				}
			}
		}
	}

sub url
	{
	my $self=shift;
	if(!$self->is_temporary)
		{
		return "${sitepath}users/".cgiencode($self->id).".html";
		}
	else
		{
		return "${sitepath}users/me.html";
		}
	}

sub editurl
	{
	my $self=shift;
	if(!$self->is_temporary)
		{
		return "${sitepath}users/".cgiencode($self->id).".html?edit=1";
		}
	else
		{
		return "${sitepath}users/me.html?edit=1";
		}
	}

sub is_temporary
	{
	my $self=shift;
	if ($self->id =~ /^temp:/)
		{
		return 1;
		}
	else
		{
		return 0;
		}
	}

sub all
	{
	my $self=shift;
	my ($sth,$row);
	my @users;
	my $dbh=open_database();
	$sth=$dbh->prepare("SELECT * FROM users ORDER BY lower(name)");
	if(($sth)&&($sth->execute))
		{
		while($row=$sth->fetch)
			{
			push @users,GenreMusicDB::User->new(@{$row});
			}
		$sth->finish;
		}
	return @users;
	}

sub has_password
	{
	my $self=shift;
	my $password=shift;
	if(crypt($password,$self->password) eq $self->password)
		{
		return 1;
		}
	else
		{
		return 0;
		}
	}

sub get
	{
	my $self=shift;
	my $id=shift;
	my ($sth,$row);
	my $ret;
	my $dbh=open_database();
	$sth=$dbh->prepare("SELECT * FROM users WHERE userid=".$dbh->quote($id)." OR email LIKE ".$dbh->quote($id));
	if(($sth)&&($sth->execute))
		{
		while($row=$sth->fetch)
			{
			$ret=GenreMusicDB::User->new(@{$row});
			}
		$sth->finish;
		}
	return $ret;
	}

sub password
	{
	my $self=shift;
	my ($parentpkg,$func,$line);
	my $caller=0;
	($parentpkg,undef,$line)=caller($caller);
	(undef,undef,undef,$func)=caller($caller+1);
	while($func =~ /::(FETCH|STORE|AUTOLOAD)$/)
		{
		($parentpkg,undef,$line)=caller(++$caller);
		(undef,undef,undef,$func)=caller($caller+1);
		}
	if(($parentpkg eq ref($self))||($func eq "GenreMusicDB::User::password"))
		{
		return $self->{"password"};
		}
#	$caller=0;
#	while($caller<20)
#		{
#		($parentpkg,undef,$line)=caller($caller++);
#		print STDERR "$parentpkg.$line\n";
#		}
#	die "$parentpkg.$line: invalid access to password";
	return "[SECRET]";
	}

sub roles
	{
	my $self=shift;
	my @roles;
	my ($sth,$row);
	my $dbh=open_database();
	if(!defined($self->{"_roles"}))
		{
		$self->{"_roles"}={};
		$sth=$dbh->prepare("SELECT * FROM roles WHERE roleid IN (SELECT roleid FROM role_members WHERE userid=".$dbh->quote($self->id).")");
		if(($sth)&&($sth->execute))
			{
			while($row=$sth->fetch)
				{
				$self->{"_roles"}->{lc($row->[0])}=GenreMusicDB::Role->new(@{$row});
				}
			$sth->finish;
			}
		}
	@roles=values %{$self->{"_roles"}};
	return \@roles;
	}

sub has_role
	{
	my $self=shift;
	my $roleid=shift;
	
	if(ref($roleid) eq "GenreMusicDB::Role")
		{
		$roleid=$roleid->id;
		}
	if(!defined($self->{"_roles"}))
		{
		$self->roles();
		}
	return defined($self->{"_roles"}->{$roleid});
	}

1;
