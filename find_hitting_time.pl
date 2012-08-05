#!/usr/bin/perl

use strict;
use warnings;

my $graph_file = shift;
my $data_file = shift;

open GRAPH, $graph_file or die $!;

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

#print "187 -- 188: ".get_sampled_hitting_time("187", "188", $graph, $NUM_SAMPLES)."\n";
#print "392 -- 394: ".get_sampled_hitting_time("392", "394", $graph, $NUM_SAMPLES)."\n";

my @aids = `cat $data_file | awk -F " ::: " '{print \$1}'`;
map(chomp($_), @aids);

for(my $i = 0; $i <= $#aids; $i++) {
    for(my $j = $i+1; $j <= $#aids; $j++) {

	# if(($aids[$i] eq "392" && $aids[$j] eq "404") || ($aids[$i] eq "404" && $aids[$j] eq "392")) {
	#     print "here";
	# }

	# if(($aids[$i] eq "187" && $aids[$j] eq "193") || ($aids[$i] eq "193" && $aids[$j] eq "187")) {
	#     print "here";
	# }

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

    print "$source -> ";

    if($source eq $target) {
	print "FOUND\n";
	return $iter;
    } 

    if($iter > $MAX_ITER) {
	print "FAIL_MAXED\n";
	return $MAX_ITER;
    }

    my $potential_hops = $graph->{$source};

    if(!defined $potential_hops) {
	print "FAIL_NOHOP\n";
	return $MAX_ITER;
    }
    my $num_hops = scalar(@{$potential_hops});
    my $hop = $potential_hops->[rand($num_hops)];

    return 1 + get_hitting_time($hop, $target, $graph, $iter+1);
}
