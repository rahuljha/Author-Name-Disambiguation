#!/usr/bin/perl

use strict;
use warnings;

my %cids = ();

my $cnt = 1;
my $CUTOFF = 60;

while(<>) {
    chomp($_);
    
    my ($a1, $a2, $ht) = split(/\s+/, $_);
    my ($id1, $id2);
    if(exists $cids{$a1}) {
	$id1 = $cids{$a1};
    }else {
	$id1 = $cnt;
	$cnt++;
	$cids{$a1} = $id1;
    }

    if($ht < $CUTOFF) {
	$id2 = $id1;
	$cids{$a2} = $id2;
    } elsif(!exists $cids{$a2}) {
	$id2 = $cnt;
	$cnt++;
	$cids{$a2} = $id2;
    }
    
}

foreach my $aid (keys %cids){
    print $aid." ".$cids{$aid}."\n";
}
