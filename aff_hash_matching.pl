#!/usr/bin/perl

use strict;
use warnings;

use utf8;
use Text::Unidecode;

# reads in a data file
# matches authors according to affiliations
# outputs the clusters

my %aff_clusters = ();

while(<>) {
    my ($aid, $cid, $curauth, $pid, $t2, $t3, $email, $aff) = split(/ ::: /, $_);
    my $hash_str = unidecode($aff);
    #TODO: remove affiliation stop words
    unless(!(defined $hash_str) || $hash_str eq "") {
	$hash_str =~ s/[[:punct:]\d]//g;
	$hash_str =~ s/\s+//g;
    }

    $hash_str = lc($hash_str);
    $aff_clusters{$hash_str} = [] unless exists $aff_clusters{$hash_str};
    push(@{$aff_clusters{$hash_str}}, $aid);
}

my $cnt = 1;
foreach my $aff (keys %aff_clusters) {
    my $aids = $aff_clusters{$aff};
    if($aff eq "") {
	foreach my $aid (@$aids) {
	    print "$aid $cnt\n";
	    $cnt++;
	}
    } else {
	foreach my $aid (@$aids) {
	    print "$aid $cnt\n";
	}
	$cnt++;
    }
}
