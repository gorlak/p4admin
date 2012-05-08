package PerforceAdmin;

use strict;

# core libs
use File::Spec;
use File::Path;
use File::Basename;

# custom libs
use PerforceMail;

# deduce the name of this script that is running
my $g_ScriptName = $0;
$g_ScriptName =~ s/\\/\//g;
$g_ScriptName =~ s/\/\//\//g;
$g_ScriptName = basename $g_ScriptName, ".pl";

# deduce the dir the script is running from
my $g_ScriptDir = dirname $0;

# make name for our log file
my $g_LogFile ="$g_ScriptName.log";

sub ScriptDir
{
  return $g_ScriptDir;
}

sub NetworkStorage
{
  my $computer = shift;
  
  if ( !defined $computer )
  {
    $computer = $ENV{ COMPUTERNAME };
  }
  
  return File::Spec->catfile( $ENV{ PERFORCE_NETWORK_STORAGE }, $computer );  
}

sub Startup
{
  # check the declaration of the network storage location  
  die "PERFORCE_NETWORK_STORAGE is not defined in the environment" if not defined $ENV{ PERFORCE_NETWORK_STORAGE };

  # check the definition of the computer name
  die "COMPUTERNAME is not defined in the environment" if not defined $ENV{ COMPUTERNAME };

  # rotate the log file for this script
  system( File::Spec->catfile( $g_ScriptDir, "rotate_log.pl" ) . " $g_LogFile 10" );

  # redirect all the output of this to the log file
  open(STDOUT, '>', $g_LogFile) || die "Can't redirect stdout";
  open(STDERR, ">&STDOUT")    || die "Can't redirect stderr";

  # make unbuffered
  select STDOUT;
  $| = 1; 
  select STDERR;
  $| = 1;

  # dump server info
  system( "p4 info" );
}

sub Shutdown
{
  # stop redirecting output
  close(STDERR);
  close(STDOUT);

  # gather the log text
  open( LOG, $g_LogFile );
  my @lines = <LOG>;
  close( LOG );

  # send notification that we are starting the script
  PerforceMail::SendMessage( "$g_ScriptName completed on $ENV{COMPUTERNAME}", join( '', @lines ), $g_LogFile );
}

sub Exit
{
  my $code = shift;

  Shutdown();
  
  exit( $code );
}

sub Execute
{
  my $command = shift;
  
  my $startTime = time;
  print("\n>>>> Executing: $command\n");
  system($command);
  
  my $elapsed = time - $startTime;
  my $elapsedTime = sprintf( "%dm, %ds", int $elapsed / 60, $elapsed % 60 ); 
  print("<<<< Took $elapsedTime\n");
  
  return $? >> 8;
}

sub Trace
{
  my $command = shift;

  my $startTime = time;
  print("\n>>>> Executing: $command\n"); 
  my @result = `$command`;
  print("@result");

  my $elapsed = time - $startTime;
  my $elapsedTime = sprintf( "%dm, %ds", int $elapsed / 60, $elapsed % 60 ); 
  print("<<<< Took $elapsedTime\n");

  return @result;
}

sub Publish
{
  my $file = shift;
  
  # publish the journal backup to network storage
  if ( defined $file )
  {
    # create the target directory
    my $mkpathErrors = [ ];
    mkpath( PerforceAdmin::NetworkStorage(), { error => \$mkpathErrors } );
    if ( @$mkpathErrors )
    {
      print("Unable to mkpath '" . PerforceAdmin::NetworkStorage() . "'\n");
      Exit( 1 );
    }

    # copy journal file to backup location
    PerforceAdmin::Execute("copy /v $file " . PerforceAdmin::NetworkStorage());

    # check the copy result
    if ( $? eq 0 )
    {
      # erase local copy
      PerforceAdmin::Execute("del /f $file");
    }
    else
    {
      # do NOT delete the local file
      print "Failed to copy '$file' to '" . PerforceAdmin::NetworkStorage() . "'\n";
    }
  }
}

1;
