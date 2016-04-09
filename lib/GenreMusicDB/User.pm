package GenreMusicDB::User;

use strict;
use GenreMusicDB::Base;
use MIME::Entity;

my @saltchars=("0".."9","a".."z","A".."Z");

sub new
	{
	my $this=shift;
	my $class=ref($this) || $this;
	my $self=bless {},$class;
	$self->{"id"}=shift;
	$self->{"name"}=shift;
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
			my @users;
			my ($sth,$row);
			my $dbh=open_database();
			$sth=$dbh->prepare("SELECT * FROM users WHERE userid NOT LIKE 'temp:%' ORDER BY lower(name)");
			if(($sth)&&($sth->execute))
				{
				while($row=$sth->fetch)
					{
					push @users,GenreMusicDB::User->new(@{$row});
					}
				$sth->finish;
				}
	
			return load_template($env,200,"user_index","List of Users",
				{mainmenu => build_mainmenu($env),users => \@users});
			}
		elsif($env->{"PATH_INFO"} =~ m%^/users/new.html?$%)
			{
			return load_template($env,200,"new_user","Invite a Friend",
				{mainmenu => build_mainmenu($env)});
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
			$sth=$dbh->prepare("SELECT * FROM users WHERE userid LIKE ".$dbh->quote($userid));
			if(($sth)&&($sth->execute))
				{
				if($row=$sth->fetch)
					{
					$user=GenreMusicDB::User->new(@{$row});
					}
				$sth->finish;
				}
			if($user)
				{
				my $req = Plack::Request->new($env);
				my $query=$req->parameters;
				if($query->{"edit"})
					{
					if($user->{"id"} eq $env->{"REMOTE_USER"})
						{
						return load_template($env,200,"edit_user","Edit ".$user->{"name"},
							{mainmenu => build_mainmenu($env),user => $user});
						}
					else
						{
						return error403($env);
						}
					}
				else
					{
					return load_template($env,200,"user",$user->{"name"},
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
		if($query->{"delete"})
			{
			}
		else
			{
			my $user;
			if($query->{"userid"})
				{
				my ($sth,$row);
				$sth=$dbh->prepare("SELECT * FROM users WHERE userid=".$dbh->quote($query->{"userid"}));
				if(($sth)&&($sth->execute))
					{
					if($row=$sth->fetch)
						{
						$user=GenreMusicDB::User->new(@{$row});
						}
					$sth->finish;
					}
				}
			else
				{
				$user=GenreMusicDB::User->new();
				}
			if(!$user)
				{
				return error500($env);
				}
			else
				{
				my $ok=$dbh->do("BEGIN");
				if($user->{"id"})
					{
					$ok=$dbh->do("UPDATE users SET ".join(",",map $_."=".$dbh->quote($query->{$_}),
						("name","email"))." WHERE userid=".$dbh->quote($query->{"userid"})) if($ok);

					if($ok)
						{
						$dbh->do("COMMIT");
						return [ 302, [ 'Location' => "http://".$env->{"HTTP_HOST"}.$user->url],[] ];
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
					$ok=$dbh->do("INSERT INTO users (userid,name,email,password) VALUES (".join(",",map $dbh->quote($_),
						($newid,$query->{"name"},$query->{"email"},$password)).")") if($ok);
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
						my $otheruser=GenreMusicDB::User->find($env->{"REMOTE_USER"});
						my $vars=
							{
							"sitepath" => $sitepath,
							"curruser" => $env->{"REMOTE_USER"} || "",
							"siteurl" => "http".($env->{"SERVER_PORT"}==443 ? "s" : "")."://".$env->{"HTTP_HOST"}.($env->{"SCRIPT_NAME"}|| "/")."?utm_medium=email&utm_source=body&utm_campaign=invite",
							"otheruser" => $otheruser,
							"password" => $newpassword,
							};
						if(($template->process("email_invite_text.tmpl",$vars,\$text))&&
							($template->process("email_invite_html.tmpl",$vars,\$html)))
							{
							if(open(MAIL,"|/usr/lib/sendmail -t -f postmaster\@thingsilove.org.uk"))
								{
								my $mimemail = MIME::Entity->build(Type => "multipart/alternative",
									From => "Chris <chris\@instituteofcorrection.org.uk>",
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
								return [ 302, [ 'Location' => "http://".$env->{"HTTP_HOST"}.$sitepath."invite_sent.html"],[] ];
								}
							else
								{
								$dbh->do("ROLLBACK");
								return error500($env);
								}
							}
						else
							{
							$dbh->do("ROLLBACK");
							return error500($env);
							}
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
	}

sub url
	{
	my $self=shift;
	return "${sitepath}users/".cgiencode($self->{"id"}).".html";
	}

sub editurl
	{
	my $self=shift;
	if($self->{"id"} !~ /^temp:/)
		{
		return "${sitepath}users/".cgiencode($self->{"id"}).".html?edit=1";
		}
	else
		{
		return "${sitepath}users/me.html?edit=1";
		}
	}

sub find
	{
	my $self=shift;
	my $userid=shift;
	my $user;
	my $dbh=open_database();
	my ($sth,$row);
	$sth=$dbh->prepare("SELECT * FROM users WHERE userid LIKE ".$dbh->quote($userid));
	if(($sth)&&($sth->execute))
		{
		if($row=$sth->fetch)
			{
			$user=GenreMusicDB::User->new(@{$row});
			}
		$sth->finish;
		}
	return $user;
	}

sub is_temporary
	{
	my $self;
	return ($self->{"id"} =~ /^temp:/);
	}
1;
