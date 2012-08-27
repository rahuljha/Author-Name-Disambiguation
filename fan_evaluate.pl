#!/usr/bin/perl

use strict;
use warnings;

# input: gold clusters, pred clusters
# output: precision, recall, f-measure

my $gold_file = shift;
my $ap_file = shift;
my $id_map_file = shift;

# create hashes

my $gold_clusters = create_hash($gold_file);
my $pred_clusters = create_ap_hash($ap_file, $id_map_file);

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

sub create_ap_hash {
    my $ap_results = shift;
    my $id_map_file = shift;

    my $hash = {};
    
    open IDMAP, $id_map_file or die $!;
    my %id_map = ();
    while(<IDMAP>) {
	chomp($_);
	my ($dblp_id, $ap_id) = split(/\s+/, $_);
	$id_map{$ap_id} = $dblp_id;
    }

    my $cur_id = 1;
    open AP_RESULT, $ap_results or die $!;
    while(<AP_RESULT>) {
	chomp($_);
	$_ =~ s/^\s+//;
	$_ =~ s/\s+$//;

	my $dblp_id = $id_map{$cur_id};
	
	$hash->{$dblp_id} = $_;
	$cur_id++;
    }

    return $hash;
}
