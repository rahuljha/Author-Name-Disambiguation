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
my $ri = ($tp+$tn) / ($tp+$fp+$fn+$tn);
my $purity = compute_purity($pred_clusters, $gold_clusters);
my $nmi = compute_nmi($pred_clusters, $gold_clusters);

printf("P: %.2f, R: %.2f, F: %.2f, RI: %.2f, Purity: %.2f, NMI: %.2f\n", $p, $r, $f, $ri, $purity, $nmi);

sub compute_nmi {
    # based on Information Retrieval, page 358
    my $pred_labels = shift;
    my $gold_labels = shift;

    my $pred_clusters = {};
    while(my ($aid, $cid) = each %$pred_labels) {
	$pred_clusters->{$cid} = [] unless exists $pred_clusters->{$cid};
	push(@{$pred_clusters->{$cid}}, $aid);
    }

    my $gold_clusters = {};
    while(my ($aid, $cid) = each %$gold_labels) {
	$gold_clusters->{$cid} = [] unless exists $gold_clusters->{$cid};
	push(@{$gold_clusters->{$cid}}, $aid);
    }
    
    my $I = 0;
    my @aids = keys %$pred_labels;
    my $N = @aids;

    foreach my $k (keys %$pred_clusters) {
	foreach my $j (keys %$gold_clusters) {
	    my $wk = $pred_clusters->{$k}; 
	    my $cj = $gold_clusters->{$j};
	    my $common = 0;
	    foreach my $id (@$wk) {
		$common++ if in_array($cj, $id);
	    }
	    my $w_cnt = $#{$wk}+1;
	    my $c_cnt = $#{$cj}+1;
	    next if $common == 0;
	    $I += ($common/$N) * log(($N*$common)/($w_cnt*$c_cnt));
	}
    }

    my $H_pred = entropy($pred_clusters, $N);
    my $H_gold = entropy($gold_clusters, $N);

    return $I / (($H_pred + $H_gold)/2)

}

sub entropy {
    my $clusters = shift;
    my $N = shift;
    my $entropy = 0;

    foreach my $k (keys %$clusters) {
	my $wk = $clusters->{$k};
	my $w_cnt = $#{$wk}+1;
	$entropy -= ($w_cnt/$N) * log($w_cnt/$N);
    }

    return $entropy;
}

sub compute_purity {
    my $pred_labels = shift;
    my $gold_labels = shift;

    my $pred_clusters = {};
    while(my ($aid, $cid) = each %$pred_labels) {
	$pred_clusters->{$cid} = [] unless exists $pred_clusters->{$cid};
	push(@{$pred_clusters->{$cid}}, $aid);
    }

    my $total_correct = 0;
    my $total = keys %$pred_labels;

    foreach my $cid (keys %$pred_clusters) {
	my $counts = {};
	my $max_count = 0;
	my $max_label = '';
	my $aids = $pred_clusters->{$cid};
	foreach my $aid (@$aids) {
	    my $gid = $gold_labels->{$aid};
	    $counts->{$gid} = 0 unless exists $counts->{$gid};
	    $counts->{$gid}++;
	    if($counts->{$gid} > $max_count) {
		$max_count = $counts->{$gid};
		$max_label = $gid;
	    }
	}
	$total_correct += $max_count;
    }
    return $total_correct/$total;
}

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

sub in_array {
     my ($arr,$search_for) = @_;
    my %items = map {$_ => 1} @$arr; # create a hash out of the array values
    return (exists($items{$search_for}))?1:0;
}
