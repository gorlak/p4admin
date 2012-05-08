package PerforceMail;

use strict;

# core libs
use Net::SMTP;

my $g_Server = $ENV{ P4ADMIN_MAILSERVER };
my $g_From = $ENV{ P4ADMIN_MAILFROM };
my $g_To = $ENV{ P4ADMIN_MAILTO };

sub SendMail
{
  my %args = @_;

  # connect to an SMTP server
  my $smtp = Net::SMTP->new( $args{ Server } );
  
  # use the sender's address here
  $smtp->mail( $args{ From } );
  
  # recipient's address
  $smtp->to( $args{ To } );
  
  # Start the mail
  $smtp->data();

  # Send the header
  $smtp->datasend("To: $args{ To }\n");
  $smtp->datasend("From: $args{ From }\n");
  $smtp->datasend("Subject: $args{ Subject }\n");
  $smtp->datasend("MIME-Version: 1.0\n");
  $smtp->datasend("Content-type: multipart/mixed;boundary=\"boundary\"\n");

  # Send the body
  $smtp->datasend("--boundary\n");
  $smtp->datasend( $args{ Message } );

  # Send the attachment
  if ( defined $args{ Attachment } )
  {
    $smtp->datasend("--boundary\n");
    $smtp->datasend("Content-type: text/plain\n");
    $smtp->datasend("Content-Disposition: attachment; filename=\"$args{ Attachment }\"\n");
    $smtp->datasend("Content-Type: application/text; name=$args{ Attachment }\n");

    my $text;
    open( TEXT, "$args{ Attachment }" );
    while( my $line = <TEXT> ) { $text .= $line; }
    $smtp->datasend($text);
  }

  # End the mail
  $smtp->dataend();
  
  # Close the SMTP connection
  $smtp->quit;
}

sub SendMessage
{
  my $subject = shift;
  my $message = shift;
  my $attachment = shift;

  SendMail( Server      => $g_Server,
            From        => $g_From,
            To          => $g_To,
            Subject     => $subject,
            Message     => $message,
            Attachment  => $attachment );
}

1;