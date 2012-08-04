#!/usr/bin/perl

use strict;
use warnings;

# input: gold clusters, pred clusters
# output: precision, recall, f-measure

my $gold_file = shift;
my $pred_file = shift;

# create hashes

my $gold_clusters = create_hash($gold_file);
my $pred_clusters = create_hash($pred_file);

# create pairs
my @aids = keys %{$pred_clusters};

my $tp = 0;
my $tn = 0;
my $fp = 0;
my $fn = 0;

for(my $i = 0; $i <= $#aids; $i++) {
    for(my $j = $i+1; $j <= $#aids; $j++) {
	my $res_pred = ($pred_clusters->{$aids[$i]} eq $pred_clusters->{$aids[$j]});
	my $res_gold = ($gold_clusters->{$aids[$i]} eq $gold_clusters->{$aids[$j]});

	if($res_gold) {
	    if($res_pred) {
		$tp++;
	    } else {
		$fn++;
	    }
	} else {
	    if($res_pred) {
		$fp++;
	    } else {
		$tn++;
	    }
	}
    }
}

my $p = ($tp+$fp == 0) ? 0 : $tp/($tp+$fp);
my $r = ($tp+$fn == 0) ? 0 : $tp/($tp+$fn);
my $f = ($p+$r == 0) ? 0 : (2 * $p * $r) / ($p + $r);

printf("P: %.2f, R: %.2f, F: %.2f\n", $p, $r, $f);

sub create_hash {
    my $file = shift;
    open FILE, $file or die $!;

    my $hash = {};

    while(<FILE>) {
	chomp($_);
	my ($aid, $cid) = split(/\s+/, $_);
	$hash->{$aid} = $cid;
    }
    return $hash;
}
