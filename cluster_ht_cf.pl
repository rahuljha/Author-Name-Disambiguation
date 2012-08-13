#!/usr/bin/perl

use strict;
use warnings;

use Clair::Network;
use Clair::Network::CFNetwork;

my $cids = {};

my $aids = {};

my $file_to_cluster = shift;
my $out_file = shift;

open FILE, $file_to_cluster or die $!;

my $key = "author_disambiguation";

my $CUTOFF = 20;

my $cnt = 1;

my $cfnw = Clair::Network::CFNetwork->new(name => $key);
while(<FILE>) {
    chomp($_);
    
    my ($a1, $a2, $ht) = split(/\s+/, $_);
    $aids->{$a1} = 1 unless exists $aids->{$a1};
    $aids->{$a2} = 1 unless exists $aids->{$a2};

    my $sim = 100 - $ht;
    $sim = 0 if $sim < 0;
    if($sim >= $CUTOFF) {
	$cfnw->add_weighted_edge($a1, $a2, $sim);
    }
    
}

my $subcfnw = $cfnw->getConnectedComponent(1);
$subcfnw->communityFind(dirname => "temp", skip_connection_test => 1);

my $comms = {};
my $max_cid = 0;
open COMMS, "./temp/$key.1.bestComm" or die $!;
while(<COMMS>) {
    chomp($_);
    my ($id, $cid) = split(/\s+/, $_);
    $comms->{$id} = $cid;
    $max_cid = $cid if $cid > $max_cid;
}

my $curr_cid = ++$max_cid;
foreach my $aid (keys %$aids) {
    $comms->{$aid} = $curr_cid++ unless(exists $comms->{$aid}) 
}

open OUT, ">./$out_file" or die $!;

foreach my $aid (keys %$comms) {
    print OUT $aid." ".$comms->{$aid}."\n";
}

close OUT;
