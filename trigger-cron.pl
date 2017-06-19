#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use Time::Local;
use LWP::UserAgent ();

# Debugging output
my $debug=1;

# Protocol (e.g. http)
my $proto="http";

# Shinobi server
my $server="localhost";

# Shinobi port
my $port=8080;

# Shinobi group key
my $groupkey="mycams";

# For now we must have direct access to the directory,
# in future release we get the videos over shinobi api.
# Shinobi base dir
my $shinobidir="/opt/shinobi";

# Shinobi video base dir with group
my $videobase="$shinobidir/videos/$groupkey";

# Shinobi API key
my $apikey="APIKEYABCDEFG";

# Hash with MonitorID -> IP
my %camips = (
  "mycam1" => "192.168.7.51",
  "mycam2" => "192.168.7.52",
  "mycam3" => "192.168.7.53",
);

# Length of videos per camera
my %camvlengths = (
  "mycam1" => 300,
  "mycam2" => 300,
  "mycam3" => 300,
);

# videolength in seconds (default)
my $videolength=300;

# how long the trigger events have to be stored in the database
# (in seconds). E.g. one day = 86400
my $triggerhistory=86400;

# Trigger DB credentials
my ($db_user, $db_name, $db_pass) = ('camtriggers', 'camtriggers', 'somepass');

# deleteVideo
# 
# deletes a video via Shinobi api
sub deleteVideo 
{
  my ($camid,$filename)=@_;
  my $ua = LWP::UserAgent->new;
  $ua->timeout(10);
  my $resp = $ua->get("$proto://$server:$port/$apikey/videos/$groupkey/$camid/$filename/delete");

  # Freeing resources
  undef $ua;

  $debug && print $resp->decoded_content . "\n";
  #    "ok": true
  return $resp->decoded_content =~ /"ok": true/m;
}

sub parsedate { 
  my($s) = @_;
  my($year, $month, $day, $hour, $minute, $second);

  if($s =~ /^\s*(\d{1,4})\-(\d{1,2})\-(\d{1,2})T(\d{1,2})\-(\d{1,2})\-(\d{1,2})\./) {
    $year = $1;  $month = $2;   $day = $3;
    $hour = $4;  $minute = $5;  $second = $6;
    $year = ($year<100 ? ($year<70 ? 2000+$year : 1900+$year) : $year);
    return timelocal($second,$minute,$hour,$day,$month-1,$year);  
  }
  return -1;
}


######
#
# Main 
#
###### 

$debug && print "\n" . localtime . " $0 started.\n";
# Connecting to trigger db
my $dbh = DBI->connect("DBI:mysql:database=$db_name", $db_user, $db_pass);

my $now = time;

foreach my $camid (keys %camips)
{
  my $camip=$camips{$camid};

  my $vlist=`ls $videobase/$camid/`;

  foreach my $vid (split (/\n/, $vlist))
  {
    $debug && print "camid=$camid vid=$vid ";
    # vid=2017-06-14T12-50-00.mp4

    chomp ($vid);
    my $vidts=parsedate($vid);

    if ($vidts == -1)
    {
      # TODO: not recognized file
      print STDERR "\nFile $vid seems to have a wrong file name format!\n";
      next;
    }

    my $vidtsend=$vidts+$videolength;
    if (exists $camvlengths{$camid})
    {
      $vidtsend=$vidts+$camvlengths{$camid};
    }

    $debug && print "vidts=$vidts vidtsend=$vidtsend ";

    # Older videos than the time storing triggers should be
    # unconsidered
    if ($now - $triggerhistory > $vidtsend)
    {
      next;
    }

    my $stm = "select count(timestamp) from triggers where timestamp >= '$vidts' and timestamp <= '$vidtsend';";
    # $debug && print "stm=$stm ";
    my $q = $dbh->prepare($stm);
    $q->execute();
    (my ($col1) = $q->fetchrow_array());
    $debug && print "col1=$col1 ";

    # delete videos if there was no triggers in the
    # time range and if the video is older than $videolength
    if (($col1 == 0) && ($vidts + $videolength < $now))
    {
      $debug && print "to be deleted! ";
      # delete from both: filesystem and Shinobi DB (via API)
      unlink ("$videobase/$camid/$vid");
      deleteVideo($camid,$vid);
    }

    $debug && print "\n";
  }
}

# delete older trigger events
$debug && print "Deleting old triggers... ";
my $stm = "delete from triggers where timestamp < " . int($now - $triggerhistory) . ";";
my $ret = $dbh->do($stm);
$debug && print "$ret\n";



