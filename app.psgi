#!/usr/bin/perl

use strict;
use Apache::DBI;
use MIME::Types;
use Date::Format;
use Plack::Request;
use Digest::MD5 qw(md5_hex);
use GenreMusicDB::Base;
use GenreMusicDB::Song;
use GenreMusicDB::User;
use GenreMusicDB::Album;
use GenreMusicDB::Artist;
use GenreMusicDB::Tag;
use GenreMusicDB::Role;

sub homepage
	{
	my $env=shift;
	my @unmoderated;
	my @newsongs;
	
	if(($curruser)&&($curruser->has_role("moderator")))
		{
		foreach my $song (GenreMusicDB::Song->all("moderated=0"))
			{
			push @unmoderated,$song;
			}
		foreach my $album (GenreMusicDB::Album->all("moderated=0"))
			{
			push @unmoderated,$album;
			}
		foreach my $artist (GenreMusicDB::Artist->all("moderated=0"))
			{
			push @unmoderated,$artist;
			}
		@unmoderated=sort { $a->added <=> $b->added } @unmoderated;
		}
	foreach my $song (GenreMusicDB::Song->all("moderated>strftime('%s','now','-7 days')"))
		{
		push @newsongs,$song;
		}

	return load_template($env,200,"html","homepage","Genre Music Database",
		{mainmenu => build_mainmenu($env),unmoderated => \@unmoderated,newsongs => \@newsongs});
	}

sub login
	{
	my $env=shift;
	if($env->{"REQUEST_METHOD"} ne "POST")
		{
		my ($olduser)=(($env->{"HTTP_COOKIE"} || "") =~ /GenreMusicDBUser=([^;]+)/);
		my $destination=$env->{"REQUEST_URI"};
		if($destination =~ m%/login.html$%)
			{
			$destination="";
			}
		return load_template($env,200,"html","login","Login",
			{mainmenu => build_mainmenu($env),destination => $destination,username => ($olduser ? $olduser : "")});
		}
	else
		{
		my $req = Plack::Request->new($env);
		my $query=$req->parameters;
		my $dbh=open_database($env);
		
		if(($query->{"username"} ne "")&&($query->{"password"} ne ""))
			{
			my $user=GenreMusicDB::User->get($query->{"username"});
			if(($user)&&($user->has_password($query->{"password"})))
				{
				my $domain=$env->{"SERVER_NAME"};
				$domain =~ s%^www\.%.%;
				my ($sth,$row);
				my $password;
				my $ok=$dbh->do("BEGIN IMMEDIATE");
				my $sth=$dbh->prepare("SELECT password FROM users WHERE userid=".$dbh->quote($user->id));
				if(($sth)&&($sth->execute))
					{
					if($row=$sth->fetch)
						{
						$password=$row->[0];
						}
					$sth->finish;
					}
				
				my $session=md5_hex(join("--",($user->id,$password,time)));
				$ok=$dbh->do("INSERT INTO sessions VALUES (".join(",",map $dbh->quote($_),($session,$user->id,$password,time,time,time,$env->{"REMOTE_ADDR"})).")") if($ok);
				$ok=$dbh->do("UPDATE users SET last_login=".time." WHERE userid=".$dbh->quote($user->id)) if($ok);
				
				if($ok)
					{
					$dbh->do("COMMIT");
					push @additionalheaders,'Set-Cookie' => "GenreMusicDB=$session; path=".$sitepath."; domain=$domain; expires=".Date::Format::time2str("%A, %d-%b-%Y %H:%M:%H %Z",time+(24*60*60));
					if($query->{"remember"})
						{
						push @additionalheaders,'Set-Cookie' => "GenreMusicDBUser=".$user->id."; path=".$sitepath."; domain=$domain; expires=".Date::Format::time2str("%A, %d-%b-%Y %H:%M:%H %Z",time+(24*60*60*365));
						}
					my $destination=$query->{"destination"};
					if($destination =~ m%^$sitepath%)
						{
						$destination="http://".$env->{"HTTP_HOST"}.$destination;
						}
					else
						{
						$destination="";
						}
						
					if($destination eq "")
						{
						$destination="http://".$env->{"HTTP_HOST"}.$sitepath;
						}
					return [ 302, [
						'Location' => $destination,
						@additionalheaders
						],[] ];
					}
				else
					{
					$dbh->do("ROLLBACK");
					return error500($env);
					}
				}
			else
				{
				return load_template($env,200,"html","login","Login",
					{mainmenu => build_mainmenu($env),destination => $query->{"destination"},errors=>["wrong"],username => $query->{"username"}});
				}
			}
		else
			{
			return load_template($env,200,"html","login","Login",
				{mainmenu => build_mainmenu($env),destination => $query->{"destination"},errors=>["wrong"],username => $query->{"username"}});
			}
		}
	}

sub logout
	{
	my $env=shift;
	my $dbh=open_database($env);
		
	my ($session)=(($env->{"HTTP_COOKIE"} || "") =~ /GenreMusicDB=([^;]+)/);
	my $domain=$env->{"HTTP_HOST"};
	$domain =~ s%^www\.%.%;
	if($session eq "")
		{
		return [ 302, [
			'Location' => "http://".$env->{"HTTP_HOST"}.$sitepath,
			@additionalheaders
			],[] ];
		}
	elsif($dbh->do("DELETE FROM sessions WHERE sessionid=".$dbh->quote($session)))
		{
		$dbh->do("UPDATE users SET last_login=".time." WHERE userid=".$dbh->quote($curruser->id));
		push @additionalheaders,'Set-Cookie' => "GenreMusicDB=; path=".$sitepath."; domain=$domain; expires=".Date::Format::time2str("%A, %d-%b-%Y %H:%M:%H %Z",0);
		return [ 302, [
			'Location' => "http://".$env->{"HTTP_HOST"}.$sitepath,
			@additionalheaders
			],[] ];
		}
	else
		{
		return error500($env);
		}
	}

sub static_content
	{
	my $env=shift;
	my $filename;
	if(( $env->{"PATH_INFO"} =~ m%^/(.*)$% )&&( -f $filepath.$1 ))
		{
		$filename=$filepath.$1;
		}
	elsif(( $env->{"PATH_INFO"} =~ m%^/(.*/?)$% )&&( -d $filepath.$1 )&&( -f $filepath."$1/index.html" ))
		{
		$filename=$filepath.$1."/index.html";
		}
	else
		{
		die "Invalid filename ".$env->{"PATH_INFO"};
		}

	my $mimetypes=new MIME::Types;
	my $type=$mimetypes->mimeTypeOf($filename);
	open my $fh, "<:raw",$filename or die $env->{"PATH_INFO"}.": ".$!;
	return [ 200, [ 'Content-Type' => $type,@additionalheaders],$fh ];
	}

my $app = sub
	{
	my $env=shift;
	my ($session)=(($env->{"HTTP_COOKIE"} || "") =~ /GenreMusicDB=([^;]+)/);
	$sitepath=$env->{"SCRIPT_NAME"} || "/";
	$filepath=($env->{"DOCUMENT_ROOT"} || ".").$sitepath;
	$curruser=undef;
	if($session)
		{
		my $dbh=open_database($env);
		my $sth;
		$sth=$dbh->prepare("SELECT sessions.userid,sessions.last_cookie FROM sessions JOIN users ON sessions.userid=users.userid AND sessions.password=users.password WHERE sessionid=".$dbh->quote($session));
		if(($sth)&&($sth->execute))
			{
			my $row;
			if($row=$sth->fetch)
				{
				$env->{"REMOTE_USER"}=$row->[0];
				$curruser=GenreMusicDB::User->get($env->{"REMOTE_USER"});
				$sth->finish;
				if($curruser)
					{
					if(time-$row->[1]>3600)
						{
						my $domain=$env->{"SERVER_NAME"};
						$domain =~ s%^www\.%.%;
						$dbh->do("UPDATE sessions SET last_cookie=".time.",last_active=".time." WHERE sessionid=".$dbh->quote($session));
						push @additionalheaders,'Set-Cookie' => "GenreMusicDB=$session; path=".$sitepath."; domain=$domain; expires=".Date::Format::time2str("%A, %d-%b-%Y %H:%M:%H %Z",time+(24*60*60));
						}
					else
						{
						$dbh->do("UPDATE sessions SET last_active=".time." WHERE sessionid=".$dbh->quote($session));
						}
					}
				}
			else
				{
				# Add some way of deleting the session cookie
				}
			}
		}
	if( $env->{"PATH_INFO"} =~ m%\.\./%)
		{
		return error500($env);
		}
	elsif(( $env->{"PATH_INFO"} =~ m%^/(.*\.(css|txt|js|jpg|gif|png|html|ico))$% )&&( -f $filepath.$1 ))
		{
		return static_content($env);
		}
	elsif(( $env->{"PATH_INFO"} =~ m%^/(fonts/.*)$% )&&( -f $filepath.$1 ))
		{
		return static_content($env);
		}
	elsif(( $env->{"PATH_INFO"} =~ m%^/(.*/?)$% )&&( -d $filepath.$1 )&&( -f $filepath."$1/index.html" ))
		{
		return static_content($env);
		}
	elsif(($env->{"REMOTE_USER"} =~ /^temp:/)&&($env->{"PATH_INFO"} !~ m%^/users/me.html$% ))
		{
		return [ 302, [ 'Location' => "http://".$env->{"HTTP_HOST"}.$sitepath."users/me.html?edit=1",@additionalheaders],[] ];
		}
	elsif($env->{"PATH_INFO"} =~ m%/env.html$% )
		{
		return [ 200, [ 'Content-Type' => 'text/plain',@additionalheaders],[map $_."=".$env->{$_}."\n", sort keys %{$env}] ];
		}
	elsif($env->{"PATH_INFO"} =~ m%^/(index.html)?$% )
		{
		return homepage($env);
		}
	elsif($env->{"PATH_INFO"} =~ m%^/login.html$% )
		{
		return login($env);
		}
	elsif($env->{"PATH_INFO"} =~ m%^/logout.html$% )
		{
		return logout($env);
		}
	elsif($env->{"PATH_INFO"} =~ m%^/invite_sent.html$% )
		{
		return load_template($env,200,"html","invite_sent","Invitation Sent",
			{mainmenu => build_mainmenu($env)});
		}
	elsif($env->{"PATH_INFO"} =~ m%^/songs/?%)
		{
		return GenreMusicDB::Song->handle($env);
		}
	elsif($env->{"PATH_INFO"} =~ m%^/albums/?%)
		{
		return GenreMusicDB::Album->handle($env);
		}
	elsif($env->{"PATH_INFO"} =~ m%^/artists/?%)
		{
		return GenreMusicDB::Artist->handle($env);
		}
	elsif($env->{"PATH_INFO"} =~ m%^/tags/?%)
		{
		return GenreMusicDB::Tag->handle($env);
		}
	elsif($env->{"PATH_INFO"} =~ m%^/users/?%)
		{
		return GenreMusicDB::User->handle($env);
		}
	elsif($env->{"PATH_INFO"} =~ m%^/roles/?%)
		{
		return GenreMusicDB::Role->handle($env);
		}
	else
		{
		return error404($env);
		}
	};
