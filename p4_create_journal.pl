use strict;

# core libs
use File::Spec;
use File::Basename;
use lib dirname $0; # add the location of this script to the lib path

# custom libs
use PerforceAdmin;

# incremental mode makes every journal file contain unique data, non-incremental just copies the journal
my $incremental = 1;

# the number of backup files to keep on hand (depends on the journal backup mode)
my $count = $incremental ? 21 : 7;

# startup (starts logging, etc...)
PerforceAdmin::Startup();

# the name of the primary server to restore from
my $primaryServer = $ENV{ PERFORCE_PRIMARY_SERVER };

# check to see which server we are
if ( defined $primaryServer )
{
  print( "PERFORCE_PRIMARY_SERVER is defined in the environment, aborting\n" );
  PerforceAdmin::Exit( 1 );
}

# the signal file that our checkpoint is complete
my $completionFile = File::Spec->catfile( PerforceAdmin::NetworkStorage(), "journal.txt" );

# delete the signal file (signalling the starting of our checkpoint generation)
unlink $completionFile;

# if the completion file has been successfully deleted
if ( -e $completionFile )
{
  print ("Unable to delete '$completionFile'\n");
  PerforceAdmin::Exit( 1 );
}

# stop perforce service
PerforceAdmin::Execute( "net stop perforce" );

# the newly created journal file
my $journal = undef;

# process the journal file
if ( $incremental )
{
  # generate and truncate journal file
  my @result = PerforceAdmin::Trace("p4d -z -jj");

  # Rotating journal to journal.####.gz...
  if ( defined @result && @result[0] =~ /Rotating journal to (.*)\.\.\./ )
  {
    # get the journal file
    $journal = $1;
  }
}
else
{
  my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime();
  my $timestamp = sprintf( "%04d%02d%02d%02d%02d%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec );

  $journal = "journal." . $timestamp . ".gz";

  PerforceUtil::GZip( "journal", $journal );
}

# start perforce service
PerforceAdmin::Execute( "net start perforce" );

# publish the journal if we succeeded
if ( defined $journal && -e $journal )
{
  # publish the journal to the network
  PerforceAdmin::Publish( $journal );

  # cleanup old journals
  PerforceAdmin::Execute( File::Spec->catfile( PerforceAdmin::ScriptDir(), "limit_numerically_named_files.pl" ) . " " . File::Spec->catfile( PerforceAdmin::NetworkStorage(), "journal" ) . " " . $count );

  # update the checkpoint file
  if ( open (FILE, ">$completionFile") )
  {
    print FILE "$journal\n";
    close FILE;
  }
  else
  {
    print ("Unable to open $completionFile for write\n");
  }
}
else
{
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
