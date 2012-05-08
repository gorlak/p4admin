use strict;

use Data::Dumper;
use File::DosGlob 'glob';

my $prefix = shift;
my $count = shift;

if ( !defined $count )
{
  print STDERR "You must specify the number of files you wish to clamp to\n";
  exit 1;
}

my @files = grep { /\.\d+/ } glob( "$prefix.*" );
if ( !@files )
{
  print STDERR "No numerically named files starting with '$prefix'\n";
  exit 1;
}

# this sort by the numeric portion without any special work
@files = sort( @files );

my $result = 0;
if ( scalar ( @files ) > $count )
{
  while ( scalar ( @files ) > $count )
  {
    my $file = shift( @files );

    if ( unlink( $file ) )
    {
      print "Deleted '$file'\n";
    }
    else
    {
      print STDERR "Unable to delete '$file': $!\n";
      $result = 1;
    }
  }
}
else
{
  print "No files to delete: " . scalar ( @files ) . " < " . $count . "\n";
}
  

exit $result;
  
