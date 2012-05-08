package PerforceUtil;

use strict;

# core libs
use Compress::Zlib;

sub GZip
{
  my $file = shift;
  my $gzfile = shift;
  
  if ( not defined $gzfile )
  {
    $gzfile = $file . ".gz";
  }

  open (FILE, $file);
  binmode FILE;

  my $buf;
  my $gz = gzopen($gzfile, "wb");
  if (! $gz)
  {
    print "Unable to write $gzfile $!\n";
  }
  else
  {
    while (my $by = sysread (FILE, $buf, 4096))
    {
      if (!$gz->gzwrite($buf))
      {
        print "Zlib error writing to $gzfile: $gz->gzerror\n";
        $gz->gzclose();
        unlink $gzfile;
        return;
      }
    }

    $gz->gzclose();
  }
}

1;