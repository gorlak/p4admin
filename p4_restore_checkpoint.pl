use strict;

# core libs
use File::Spec;
use File::Basename;
use lib dirname $0; # add the location of this script to the lib path

# custom libs
use PerforceAdmin;

# startup (starts logging, etc...)
PerforceAdmin::Startup();

# the name of the primary server to restore from
my $primaryServer = $ENV{ PERFORCE_PRIMARY_SERVER };

# check to see which server we are
if ( not defined $primaryServer )
{
  print "PERFORCE_PRIMARY_SERVER is not defined in the environment, aborting\n";
  PerforceAdmin::Exit( 1 );
}

# get the sequence number
my @journal = PerforceAdmin::Trace("p4 counter journal");

# did we get output from p4?
if ( not defined @journal )
{
  print "Unable to parse output of 'p4 counter journal', aborting\n";
  PerforceAdmin::Exit( 1 );
}

# attempt to parse the sequence number
my $currentSequence = undef;

# ####
if ( @journal[0] =~ /^(\d+)$/ )
{
  $currentSequence = $1;
}
else
{
  print "Unable to get sequence number, aborting\n";
  PerforceAdmin::Exit( 1 );
}

# the completion file that signals the end of a checkpoint operation
my $completionFile = File::Spec->catfile( PerforceAdmin::NetworkStorage( $primaryServer ), "checkpoint.txt" );    

# let the log know we waited
if ( !-e $completionFile )
{
  print "Waiting for '$completionFile'\n";
}

# wait for the completion file to be written
my $interval = 2; # secs between checks
my $timeout = 60 * 60 * 12; # 12 hours
while ( !-e $completionFile && $timeout > 0 )
{
  $timeout -= $interval;
  sleep $interval;
}

my $checkpointSequence = undef;

# get the sequence number from the completion file
if ( open (FILE, "<$completionFile") )
{
  $checkpointSequence = <FILE>;
  close (FILE);

  chomp $checkpointSequence;

  if ( $checkpointSequence =~ /checkpoint\.(\d+)\.gz/ )
  {
    $checkpointSequence = $1;
  }
  else
  {
    print ("Contents of $completionFile is not formatted correctly: '$checkpointSequence'\n");
    PerforceAdmin::Exit( 1 );
  }
}
else
{
  print ("Unable to open $completionFile for read\n");
  PerforceAdmin::Exit( 1 );
}

if ( $checkpointSequence > $currentSequence )
{
  # build a path to the checkpoint file
  my $checkpoint = File::Spec->catfile( PerforceAdmin::NetworkStorage( $primaryServer ), "checkpoint.$checkpointSequence.gz" );
  if ( -e $checkpoint )
  {
    # stop perforce service
    PerforceAdmin::Execute("net stop perforce");
    
    # rename db.* to backup.*
    if ( PerforceAdmin::Execute("ren db.* backup.*") == 0 )
    {
      # generate the checkpoint file
      if ( PerforceAdmin::Execute("p4d -z -jr \"$checkpoint\"") == 0 )
      {
        # success, delete backup.*
        PerforceAdmin::Execute("del backup.*");
      }
      else
      {
        # delete newly-stubbed db.*
        PerforceAdmin::Execute("del db.*");

        # restore backup.* to db.*
        PerforceAdmin::Execute("ren backup.* db.*");
      }
    }

    # start perforce service
    PerforceAdmin::Execute("net start perforce");
  }
  else
  {
    print ("Checkpoint '$checkpoint' does not exist\n");
  }
}
else
{
  print ("Checkpoint is old: current = '$currentSequence', checkpoint = '$checkpointSequence'\n");
}

# close and send log
PerforceAdmin::Shutdown();
