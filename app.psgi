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
	return load_template($env,200,"html","homepage","Genre Music Database",
		{mainmenu => build_mainmenu($env)});
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
			my ($sth,$row);
			$sth=$dbh->prepare("SELECT userid,password FROM users WHERE userid LIKE ".$dbh->quote($query->{"username"})." OR email LIKE ".$dbh->quote($query->{"username"}));
			if(($sth)&&($sth->execute))
				{
				if(($row=$sth->fetch)&&($row->[0])&&(crypt($query->{"password"},$row->[1]) eq $row->[1]))
					{
					$sth->finish;
					
					my $domain=$env->{"SERVER_NAME"};
					$domain =~ s%^www\.%.%;
					print STDERR "$domain\n";
					my $session=md5_hex(join("--",($row->[0],$row->[1],time)));
					if($dbh->do("INSERT INTO sessions VALUES (".join(",",map $dbh->quote($_),($session,$row->[0],$row->[1],time,time,time,$env->{"REMOTE_ADDR"})).")"))
						{
						my @cookies=('Set-Cookie' => "GenreMusicDB=$session; path=".$sitepath."; domain=$domain");
						if($query->{"remember"})
							{
							push @cookies,'Set-Cookie' => "GenreMusicDBUser=".$row->[0]."; path=".$sitepath."; domain=$domain; expires=".Date::Format::time2str("%A, %d-%b-%Y %H:%M:%H %Z",time+(24*60*60*365));
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
							@cookies,
							],[] ];
						}
					else
						{
						return error500($env);
						}
					}
				else
					{
					$sth->finish;
					return [ 302, [ 'Location' => "http://".$env->{"HTTP_HOST"}.$sitepath."login.html?username=".$query->{"username"}],[] ];
					}
				}
			}
		else
			{
			return [ 302, [ 'Location' => "http://".$env->{"HTTP_HOST"}.$sitepath."login.html?username=".$query->{"username"}],[] ];
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
			'Set-Cookie' => "GenreMusicDB=; path=".$sitepath."; domain=$domain; expires=".Date::Format::time2str("%A, %d-%b-%Y %H:%M:%H %Z",0),
			],[] ];
		}
	elsif($dbh->do("DELETE FROM sessions WHERE sessionid=".$dbh->quote($session)))
		{
		return [ 302, [
			'Location' => "http://".$env->{"HTTP_HOST"}.$sitepath,
			'Set-Cookie' => "GenreMusicDB=; path=".$sitepath."; domain=$domain; expires=".Date::Format::time2str("%A, %d-%b-%Y %H:%M:%H %Z",0),
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
	if(( $env->{"PATH_INFO"} =~ m%^/(.*\.(css|js|jpg|gif|png|html|ico))$% )&&( -f $filepath.$1 ))
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
	return [ 200, [ 'Content-Type' => $type],$fh ];
	}

my $app = sub
	{
	my $env=shift;
	my ($session)=(($env->{"HTTP_COOKIE"} || "") =~ /GenreMusicDB=([^;]+)/);
	$sitepath=$env->{"SCRIPT_NAME"} || "/";
	$filepath=($env->{"DOCUMENT_ROOT"} || ".").$sitepath;
	if($session)
		{
		my $dbh=open_database($env);
		my $sth;
		$sth=$dbh->prepare("SELECT sessions.userid FROM sessions JOIN users ON sessions.userid=users.userid AND sessions.password=users.password WHERE sessionid=".$dbh->quote($session));
		if(($sth)&&($sth->execute))
			{
			my $row;
			if($row=$sth->fetch)
				{
				$env->{"REMOTE_USER"}=$row->[0];
				}
			else
				{
				# Add some way of deleting the session cookie
				}
			$sth->finish;
			}
		}
	if( $env->{"PATH_INFO"} =~ m%\.\./%)
		{
		return error500($env);
		}
	elsif(( $env->{"PATH_INFO"} =~ m%^/(.*\.(css|js|jpg|gif|png|html|ico))$% )&&( -f $filepath.$1 ))
		{
		return static_content($env);
		}
	elsif(( $env->{"PATH_INFO"} =~ m%^/(.*/?)$% )&&( -d $filepath.$1 )&&( -f $filepath."$1/index.html" ))
		{
		return static_content($env);
		}
	elsif(($env->{"REMOTE_USER"} =~ /^temp:/)&&($env->{"PATH_INFO"} !~ m%^/users/me.html$% ))
		{
		return [ 302, [ 'Location' => "http://".$env->{"HTTP_HOST"}.$sitepath."users/me.html?edit=1"],[] ];
		}
	elsif($env->{"PATH_INFO"} =~ m%/env.html$% )
		{
		return [ 200, [ 'Content-Type' => 'text/plain'],[map $_."=".$env->{$_}."\n", sort keys %{$env}] ];
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
