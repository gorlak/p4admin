#!/usr/bin/perl -w

use strict;
use File::Copy;
use File::Basename;
use File::Spec;

my $file  = File::Spec->rel2abs( shift );
my $count = shift;

if ( ! -e $file )
{
  exit;
}

my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime();
my $timestamp = sprintf( "%04d%02d%02d%02d%02d%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec );

if ( !copy( $file, "$file.$timestamp" ) )
{
  print "ERROR: Could not copy '$file' to '$file.$timestamp': $!\n";
  exit;
}

if ( !unlink( $file ) )
{
  print "ERROR: Could not unlink '$file': $!\n";
  exit;
}

print "'$file' -> '$file.$timestamp'\n";

if ( defined( $count ) )
{

  my $filename = basename( $file );
  my $directory = dirname( $file );

  if ( !opendir( DIR, $directory ) )
  {
    print "ERROR: Could not open '$directory' for read: $!\n";
    exit;
  }

  my @files = readdir( DIR );
  closedir( DIR );

  chomp( @files );

  @files = grep { /^$filename/ } @files;

  @files = sort( @files );

  while( scalar( @files ) > $count )
  {
    my $oldFile = shift( @files );
    print "Removing old file: $oldFile\n";

    if ( !unlink( $oldFile ) )
    {
      print "ERROR: Could not unlink '$oldFile' during cleanup: $!\n";
    }
  }
}