use strict;

# core libs
use File::Spec;
use File::Basename;
use lib dirname $0; # add the location of this script to the lib path

# custom libs
use PerforceAdmin;

# the number of backup files to keep on hand
my $count = 3;

# startup (starts logging, etc...)
PerforceAdmin::Startup();

# the name of the primary server to restore from
my $primaryServer = $ENV{ PERFORCE_PRIMARY_SERVER };

# check to see which server we are
if ( defined $primaryServer )
{
  print "PERFORCE_PRIMARY_SERVER is defined in the environment, aborting\n";
  PerforceAdmin::Exit( 1 );
}
  
# the signal file that our checkpoint is complete
my $completionFile = File::Spec->catfile( PerforceAdmin::NetworkStorage(), "checkpoint.txt" );

# delete the signal file (signalling the starting of our checkpoint generation)
unlink $completionFile;

# if the completion file has been successfully deleted
if ( -e $completionFile )
{
  print ("Unable to delete '$completionFile'\n");
  PerforceAdmin::Exit( 1 );
}

# stop perforce service
PerforceAdmin::Execute("net stop perforce");

# the newly created files
my $checkpoint = undef;
my $journal = undef;

# generate the checkpoint file
my @result = PerforceAdmin::Trace("p4d -z -jc");

if ( defined @result )
{
  # Checkpointing to checkpoint.####.gz...
  if ( @result[0] =~ /Checkpointing to (.*)\.\.\./ )
  {
    # get the journal file
    $checkpoint = $1;
  }

  # Rotating journal to journal.####.gz...
  if ( @result[1] =~ /Rotating journal to (.*)\.\.\./ )
  {
    # get the journal file
    $journal = $1;
  }
}

# start perforce service
PerforceAdmin::Execute("net start perforce");

# publish the checkpoint if we succeeded
if ( defined $checkpoint && -e $checkpoint && defined $journal && -e $journal )
{
  # publish to the network
  PerforceAdmin::Publish( $checkpoint );
  PerforceAdmin::Publish( $journal );

  # cleanup old files
  PerforceAdmin::Execute( File::Spec->catfile( PerforceAdmin::ScriptDir(), "limit_numerically_named_files.pl" ) . " " . File::Spec->catfile( PerforceAdmin::NetworkStorage(), "checkpoint" ) . " " . $count );
  PerforceAdmin::Execute( File::Spec->catfile( PerforceAdmin::ScriptDir(), "limit_numerically_named_files.pl" ) . " " . File::Spec->catfile( PerforceAdmin::NetworkStorage(), "journal" ) . " " . ( $count * 7 ) );

  # rotate server log
  PerforceAdmin::Execute( File::Spec->catfile( PerforceAdmin::ScriptDir(), "rotate_log.pl" ) . " " . "log" . " " . $count );

  # update the checkpoint file
  if ( open (FILE, ">$completionFile") )
  {
    print FILE "$checkpoint\n";
    close FILE;
  }
  else
  {
    print ("Unable to open $completionFile for write\n");
  }
}
else
{
  if ( !defined $checkpoint )
  {
    print ("Unable to detect checkpoint file from p4d output\n");
  }
  elsif ( !-e $checkpoint )
  {
    print ("Checkpoint file '$checkpoint' does not exist\n");
  }

  if ( !defined $journal )
  {
    print ("Unable to detect journal file from p4d output\n");
  }
  elsif ( !-e $journal )
  {
    print ("Journal file '$journal' does not exist\n");
  }
}

# close and send log
PerforceAdmin::Shutdown();