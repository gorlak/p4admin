use strict;

# core libs
use File::Spec;
use File::Basename;
use lib dirname $0; # add the location of this script to the lib path

# custom libs
use PerforceAdmin;

# startup (starts logging, etc...)
PerforceAdmin::Startup();

my @process_list = PerforceAdmin::Trace( "p4 monitor show" );

foreach my $process (@process_list)
{ 
  my ( $process_id, $status, $username, $hours, $minutes, $seconds, $state ) = $process =~ m/\s*(\d+)\s+(\w+)\s+(\w+)\s+(\d+)\:(\d+)\:(\d+)\s+(\w+)/;

  if ( $status =~ "T" )
  {
    PerforceAdmin::Execute("p4 monitor clear $process_id");
  }
  elsif ( $hours > 48 )
  {
    PerforceAdmin::Execute("p4 monitor terminate $process_id");
  }
}

# close and send log
PerforceAdmin::Shutdown();