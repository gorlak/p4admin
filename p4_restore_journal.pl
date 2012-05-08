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

# the completion file that signals the end of a journal operation
my $completionFile = File::Spec->catfile( PerforceAdmin::NetworkStorage( $primaryServer ), "journal.txt" );    

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

my $journalSequence = undef;

# get the sequence number from the completion file
if ( open (FILE, "<$completionFile") )
{
  $journalSequence = <FILE>;
  close (FILE);

  chomp $journalSequence;

  if ( $journalSequence =~ /journal\.(\d+)\.gz/ )
  {
    $journalSequence = $1;
  }
  else
  {
    print ("Contents of $completionFile is not formatted correctly: '$journalSequence'\n");
    PerforceAdmin::Exit( 1 );
  }
}
else
{
  print ("Unable to open $completionFile for read\n");
  PerforceAdmin::Exit( 1 );
}

if ( $journalSequence >= $currentSequence )
{
  my @journals = ();
  my $missing = 0;

  for ( my $sequence = $currentSequence; $sequence <= $journalSequence; $sequence++ )
  {
    # build a path to the journal file
    my $journal = File::Spec->catfile( PerforceAdmin::NetworkStorage( $primaryServer ), "journal.$sequence.gz" );
    if ( -e $journal )
    {
      push( @journals, $journal );
    }
    else
    {
      print ("Journal '$journal' does not exist\n");
      $missing = 1;
    }
  }

  if ( !$missing )
  {
    my $success = 1;

    # stop perforce service
    PerforceAdmin::Execute("net stop perforce");

    foreach my $journal ( @journals )
    {
      # generate the journal file
      if ( PerforceAdmin::Execute("p4d -z -jr \"$journal\"") != 0 )
      {
        print ("Failed to restore journal '$journal'\n");
        $success = 0;
        last;
      }
    }

    # start perforce service
    PerforceAdmin::Execute("net start perforce");
  }
  else
  {
    print ("Some journal files are missing, aborting\n");
    PerforceAdmin::Exit( 1 );
  }
}
else
{
  print ("Journal files are too old: current = '$currentSequence', journal = '$journalSequence'\n");
}

# close and send log
PerforceAdmin::Shutdown();
