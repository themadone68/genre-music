#!/usr/bin/perl

use HTML::Template;

sub homepage
	{
	my $env=shift;
	my $template = HTML::Template->new(filename => $env->{"DOCUMENT_ROOT"}.$env->{"SCRIPT_NAME"}."homepage.tmpl");
	$template->param(title => "Hello World");
	return [ 200, [ 'Content-Type' => 'text/html'],[$template->output] ];
	}

sub error404
	{
	my $env=shift;
	my $template = HTML::Template->new(filename => $env->{"DOCUMENT_ROOT"}.$env->{"SCRIPT_NAME"}."error404.tmpl");
	return [ 404, [ 'Content-Type' => 'text/html'],[$template->output] ];
	}

sub error500
	{
	my $env=shift;
	my $template = HTML::Template->new(filename => $env->{"DOCUMENT_ROOT"}.$env->{"SCRIPT_NAME"}."error500.tmpl");
	return [ 500, [ 'Content-Type' => 'text/html'],[$template->output] ];
	}

sub static_page
	{
	my $env=shift;
	my $filename;
	if(( $env->{"PATH_INFO"} =~ m%^/(.*\.(css|js|jpg|gif|png|html|ico))$% )&&( -f $env->{"DOCUMENT_ROOT"}.$env->{"SCRIPT_NAME"}.$1 ))
		{
		$filename=$env->{"DOCUMENT_ROOT"}.$env->{"SCRIPT_NAME"}.$1;
		}
	elsif(( $env->{"PATH_INFO"} =~ m%^/(.*/?)$% )&&( -d $env->{"DOCUMENT_ROOT"}.$env->{"SCRIPT_NAME"}.$1 )&&( -f $env->{"DOCUMENT_ROOT"}.$env->{"SCRIPT_NAME"}."$1/index.html" ))
		{
		$filename=$env->{"DOCUMENT_ROOT"}.$env->{"SCRIPT_NAME"}.$1."/index.html";
		}
	else
		{
		die "Invalid filename ".$env->{"PATH_INFO"};
		}

	open my $fh, "<:raw",$filename or die $env->{"PATH_INFO"}.": ".$!;
	return [ 200, [ 'Content-Type' => 'text/html'],$fh ];
	}

my $app = sub
	{
	my $env=shift;

	if( $env->{"PATH_INFO"} =~ m%\.\./%)
		{
		return error500($env);
		}
	elsif($env->{"PATH_INFO"} =~ m%^/(index.html)?$% )
		{
		return homepage($env);
		}
	elsif($env->{"PATH_INFO"} =~ m%^/env.html$% )
		{
		return [ 200, [ 'Content-Type' => 'text/plain'],[map $_."=".$env->{$_}."\n", sort keys %{$env}] ];
		}
	elsif(( $env->{"PATH_INFO"} =~ m%^/(.*\.(css|js|jpg|gif|png|html|ico))$% )&&( -f $env->{"DOCUMENT_ROOT"}.$env->{"SCRIPT_NAME"}.$1 ))
		{
		return static_page($env);
		}
	elsif(( $env->{"PATH_INFO"} =~ m%^/(.*/?)$% )&&( -d $env->{"DOCUMENT_ROOT"}.$env->{"SCRIPT_NAME"}.$1 )&&( -f $env->{"DOCUMENT_ROOT"}.$env->{"SCRIPT_NAME"}."$1/index.html" ))
		{
		return static_page($env);
		}
	else
		{
		return error404($env);
		}
	};
