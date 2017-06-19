#!/usr/bin/perl
#
# Receives an email and stores the current timestamp in the database
# together with the peer's ip address.

use Carp;
use Net::SMTP::Server;
use Net::SMTP::Server::Client;
use Net::SMTP::Server::Relay;

use strict;
use warnings;
use DBI;

# Debugging output
my $debug=0;

# SMTP-Address to bind (e.g. 0.0.0.0)
my $bindip="0.0.0.0";

# SMTP-Port to be used
my $port=2525;

# Database connection
#
my ($db_user, $db_name, $db_pass) = ('camtriggers', 'camtriggers', 'somepass');

my $dbh = DBI->connect("DBI:mysql:database=$db_name", $db_user, $db_pass);

my $server = new Net::SMTP::Server($bindip, $port) ||
  croak("Unable to handle client connection: $!\n");

while(my $conn = $server->accept()) {
  my $client = new Net::SMTP::Server::Client($conn) ||
      croak("Unable to handle client connection: $!\n");

  my @k=keys(%$client);
  $"=" ";
  my $now = time;
  $debug && print "$now IP=" . $conn->peerhost() . " localtime=" . localtime . " clientkeys=@k\n";

  my $stm = "INSERT into triggers values ( '$now', '" . $conn->peerhost() . "', 'trigger-server.pl', '".localtime."' );\n";
  $debug && print "stm=$stm";
  $dbh->do($stm);

  # Process the client.  This command will block until
  # the connecting client completes the SMTP transaction.
  $client->process || next;

  # The email has to be thrown away, because we already record mjpeg.
}

