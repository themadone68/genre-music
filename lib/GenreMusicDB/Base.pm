package GenreMusicDB::Base;

use Exporter 'import';
use Apache::DBI;
use Template;

our @ISA = qw(Exporter);
our @EXPORT = qw(open_database load_template build_mainmenu error403 error404 error500 $sitepath $filepath htmlencode cgiencode);
our $sitepath;
our $filepath;
my $dbh;

sub open_database
	{
	if(!$dbh)
		{
		$dbh=DBI->connect("dbi:SQLite:".$filepath."data/database.db","","",{sqlite_unicode => 1});
		}
	return $dbh;
	}

sub load_template
	{
	my $env=shift;
	my $status=shift;
	my $name=shift;
	my $title=shift;
	my $template = Template->new(
		{
		INCLUDE_PATH => $filepath,
		FILTERS =>
			{
			"htmlencode" => \&htmlencode,
			"cgiencode" => \&cgiencode,
			}
		});
	my $vars=
		{
		"sitepath" => $sitepath,
		"title" => $title,
		"curruser" => $env->{"REMOTE_USER"} || "",
		};
	if(($#_==0)&&(ref($_[0]) eq "HASH"))
		{
		foreach my $key (keys %{$_[0]})
			{
			$vars->{$key}=$_[0]->{$key};
			}
		}
	else
		{
		for(my $i=0;$i<=$#_;$i += 2)
			{
			$vars->{$_[$i]}=$_[$i+1];
			}
		}
	
	my $result;
	if($template->process("$name.tmpl",$vars,\$result))
		{
		return [ $status, [ 'Content-Type' => 'text/html'],[$result] ];
		}
	else
		{
		return [ 500, [ 'Content-Type' => 'text/html'],[$template->error()] ];
		}
	}

sub build_mainmenu
	{
	my $env=shift;
	my @menu;
	
	if($env->{"REMOTE_USER"})
		{
		@menu=
			(
			{ url => "/", name => "Home" },
			{ url => "/songs/new.html", name => "Add Song" },
			{ url => "/users/new.html", name => "Invite" },
			{ url => "/logout.html", name => "Logout" },
			);
		}
	else
		{
		@menu=
			(
			{ url => "/", name => "Home" },
			{ url => "/login.html", name => "Login" },
			);
		}
	my $best=0;
	for(my $i=0;$i<=$#menu;$i++)
		{
		my $pattern=$menu[$i]->{"url"};
		if($pattern =~ m%/$%)
			{
			$pattern .= "?(index.html)?";
			}
		if($env->{"PATH_INFO"} =~ m%^$pattern%)
			{
			$best=$i;
			}
		}
	$menu[$best]->{"active"}=1;
	for(my $i=0;$i<=$#menu;$i++)
		{
		if($menu[$i]->{"url"} =~ m%^/%)
			{
			$menu[$i]->{"url"}=$sitepath.substr($menu[$i]->{"url"},1);
			}
		}
	return \@menu;
	}

sub error404
	{
	my $env=shift;
	return load_template($env,404,"error404","Page not found",
		{mainmenu => build_mainmenu($env)});
	}

sub error403
	{
	my $env=shift;
	return load_template($env,403,"error403","Access Denied",
		{mainmenu => build_mainmenu($env)});
	}

sub error500
	{
	my $env=shift;
	return load_template($env,500,"error500","This page isn't working",
		{mainmenu => build_mainmenu($env)});
	}

# Format a text string in a form suitable for a URL
sub cgiencode
	{
	my $in=shift;
	utf8::encode($in);
	$in =~ s/([^\!:\'A-Za-z0-9\-_.~])/sprintf("%%%02x",ord($1))/ego;
	return $in;
	}

# Format a text string in a form suitable for displaying as HTML
sub htmlencode
	{
	my $in=shift;
	
	$in =~ s/&/&amp;/sg;
	$in =~ s/([^ -~])/sprintf("&#%d;",ord($1))/sego;
	$in =~ s/"/&quot;/sg; #"
	$in =~ s/</&lt;/sg;
	$in =~ s/>/&gt;/sg;
	return $in;
	}

1;
