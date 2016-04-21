package GenreMusicDB::Base;

use Exporter 'import';
use Apache::DBI;
use Template;
use Text::Markdown qw(markdown);

our @ISA = qw(Exporter);
our @EXPORT = qw(open_database load_template build_mainmenu error401 error403 error404 error500 $sitepath $filepath htmlencode cgiencode log_error $curruser @additionalheaders);
our $sitepath;
our $filepath;
our $curruser;
our @additionalheaders;
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
	my $format=shift || "html";
	my $name=shift;
	my $title=shift;
	my $contenttype;
	my $template = Template->new(
		{
		INCLUDE_PATH => $filepath."templates/$format",
		FILTERS =>
			{
			"htmlencode" => \&htmlencode,
			"cgiencode" => \&cgiencode,
			"markdown2html" => \&markdown2html,
			}
		});
	my $vars=
		{
		"sitepath" => $sitepath,
		"title" => $title,
		"curruser" => $curruser
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
	if($format eq "json")
		{
		$contenttype="application/json";
		}
	else
		{
		$contenttype="text/html";
		}
	if($template->process("$name.tmpl",$vars,\$result))
		{
		return [ $status, [ 'Content-Type' => $contenttype,@additionalheaders],[$result] ];
		}
	else
		{
		return [ 500, [ 'Content-Type' => $contenttype,@additionalheaders],[$template->error()] ];
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
			{ url => "/search.html", name => "Search" },
			{ url => "/songs/new.html", name => "Add Song" },
			{ url => "/users/new.html", name => "Invite" },
			{ url => "/users/me.html", name => "Profile" },
			{ url => "/logout.html", name => "Logout" },
			);
		}
	else
		{
		@menu=
			(
			{ url => "/", name => "Home" },
			{ url => "/search.html", name => "Search" },
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
	return load_template($env,404,"html","error404","Page not found",
		{mainmenu => build_mainmenu($env)});
	}

sub error403
	{
	my $env=shift;
	return load_template($env,403,"html","error403","Access Denied",
		{mainmenu => build_mainmenu($env)});
	}

sub error401
	{
	my $env=shift;
	my ($olduser)=(($env->{"HTTP_COOKIE"} || "") =~ /GenreMusicDBUser=([^;]+)/);
	my $destination=$env->{"REQUEST_URI"};
	if($destination =~ m%/login.html$%)
		{
		$destination="";
		}
	return load_template($env,401,"html","login","Please Login",
		{mainmenu => build_mainmenu($env),destination => $destination,username => ($olduser ? $olduser : "")});
	}

sub error500
	{
	my $env=shift;
	return load_template($env,500,"html","error500","This page isn't working",
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

sub log_error
	{
	my $r=($ENV{MOD_PERL_API_VERSION}==2 ? Apache2::RequestUtil->request : ($ENV{MOD_PERL_API_VERSION}==1 ? Apache->request : undef));
	if($r)
		{
		$r->log_error(@_);
		}
	else
		{
		print STDERR join("",@_),"\n";
		}
	}

sub markdown2html
	{
	my $input=shift;
	return markdown($input);
	}


1;
