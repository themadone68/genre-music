#!/usr/bin/perl

use HTML::Template;
use MIME::Types;

sub homepage
	{
	my $env=shift;
	my $template = HTML::Template->new(filename => $env->{"DOCUMENT_ROOT"}.$env->{"SCRIPT_NAME"}."homepage.tmpl");
	$template->param(title => "Hello World");
	$template->param(sitepath => $env->{"SCRIPT_NAME"});
	return [ 200, [ 'Content-Type' => 'text/html'],[$template->output] ];
	}

sub error404
	{
	my $env=shift;
	my $template = HTML::Template->new(filename => $env->{"DOCUMENT_ROOT"}.$env->{"SCRIPT_NAME"}."error404.tmpl");
	$template->param(title => "Page not found");
	$template->param(sitepath => $env->{"SCRIPT_NAME"});
	return [ 404, [ 'Content-Type' => 'text/html'],[$template->output] ];
	}

sub error500
	{
	my $env=shift;
	my $template = HTML::Template->new(filename => $env->{"DOCUMENT_ROOT"}.$env->{"SCRIPT_NAME"}."error500.tmpl");
	$template->param(title => "This page isn't working");
	$template->param(sitepath => $env->{"SCRIPT_NAME"});
	return [ 500, [ 'Content-Type' => 'text/html'],[$template->output] ];
	}

sub static_content
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

	my $mimetypes=new MIME::Types;
	my $type=$mimetypes->mimeTypeOf($filename);
	open my $fh, "<:raw",$filename or die $env->{"PATH_INFO"}.": ".$!;
	return [ 200, [ 'Content-Type' => $type],$fh ];
	}

sub song_index
	{
	my $env=shift;
	my $template = HTML::Template->new(filename => $env->{"DOCUMENT_ROOT"}.$env->{"SCRIPT_NAME"}."song_index.tmpl");
	$template->param(title => "List of Songs");
	$template->param(sitepath => $env->{"SCRIPT_NAME"});
	return [ 200, [ 'Content-Type' => 'text/html'],[$template->output] ];
	}

sub song
	{
	my $env=shift;
	my $title;
	if($env->{"PATH_INFO"} =~ m%^/songs/(.*)(\.html)?$%)
		{
		$title=$1;
		}

	my $template = HTML::Template->new(filename => $env->{"DOCUMENT_ROOT"}.$env->{"SCRIPT_NAME"}."song.tmpl");
	$template->param(title => $title);
	$template->param(sitepath => $env->{"SCRIPT_NAME"});
	return [ 200, [ 'Content-Type' => 'text/html'],[$template->output] ];
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
	elsif($env->{"PATH_INFO"} =~ m%^/songs/(index.html)?$% )
		{
		return song_index($env);
		}
	elsif($env->{"PATH_INFO"} =~ m%^/songs/% )
		{
		return song($env);
		}
	elsif($env->{"PATH_INFO"} =~ m%^/env.html$% )
		{
		return [ 200, [ 'Content-Type' => 'text/plain'],[map $_."=".$env->{$_}."\n", sort keys %{$env}] ];
		}
	elsif(( $env->{"PATH_INFO"} =~ m%^/(.*\.(css|js|jpg|gif|png|html|ico))$% )&&( -f $env->{"DOCUMENT_ROOT"}.$env->{"SCRIPT_NAME"}.$1 ))
		{
		return static_content($env);
		}
	elsif(( $env->{"PATH_INFO"} =~ m%^/(.*/?)$% )&&( -d $env->{"DOCUMENT_ROOT"}.$env->{"SCRIPT_NAME"}.$1 )&&( -f $env->{"DOCUMENT_ROOT"}.$env->{"SCRIPT_NAME"}."$1/index.html" ))
		{
		return static_content($env);
		}
	else
		{
		return error404($env);
		}
	};
