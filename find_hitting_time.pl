#!/usr/bin/perl

use strict;
use warnings;

my $auth_key = shift;

open GRAPH, "./files/".$auth_key.".graph" or die $!;

my $graph = {};

my $MAX_ITER = 50;
my $NUM_SAMPLES = 100;

# read the undirected graph
while(<GRAPH>) {
    chomp($_);
    $_ =~ m/^(\d+) === (\d+)$/g;
    $graph->{$1} = [] unless exists $graph->{$1};
    $graph->{$2} = [] unless exists $graph->{$2};
    push(@{$graph->{$1}}, $2);
    push(@{$graph->{$2}}, $1);
}

close GRAPH;

my @aids = `cat ./files/$auth_key.data | awk -F " ::: " '{print \$1}'`;
map(chomp($_), @aids);

for(my $i = 0; $i <= $#aids; $i++) {
    for(my $j = $i+1; $j <= $#aids; $j++) {
	my $ht = get_sampled_hitting_time($aids[$i], $aids[$j], $graph, $NUM_SAMPLES);
	print $aids[$i]." ".$aids[$j]." ".$ht."\n";
    }
}

sub get_sampled_hitting_time {
    my $a1 = shift;
    my $a2 = shift;
    my $graph = shift;
    my $num_samples = shift;
    
    my $aht = 0;
    for(my $i = 0; $i < $num_samples; $i++) {
	$aht += get_hitting_time($a1, $a2, $graph, 1);
    }

    return $aht/$num_samples;
}

sub get_hitting_time {
    my $source = shift;
    my $target = shift;
    my $graph = shift;
    my $iter = shift;

    if($source eq $target) {
	return $iter;
    } 

    if($iter > $MAX_ITER) {
	return $MAX_ITER;
    }

    my $potential_hops = $graph->{$source};
    if(!defined $potential_hops) {
	return $MAX_ITER;
    }
    my $num_hops = scalar(@{$potential_hops});
    my $hop = $potential_hops->[rand($num_hops)];

    return 1 + get_hitting_time($hop, $target, $graph, $iter+1);
}
