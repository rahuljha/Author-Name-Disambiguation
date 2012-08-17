#!/usr/bin/perl

use strict;
use warnings;

my $graph_file = shift;
my $data_file = shift;

open GRAPH, $graph_file or die $!;

my $graph = {};

my $MAX_ITER = 10;
my $NUM_SAMPLES = 10000;

# read the undirected graph
while(<GRAPH>) {
    chomp($_);
    $_ =~ m/^(\d+) === (\d+)$/g;
    $graph->{$1}{$2} = 0 unless exists $graph->{$1}{$2};
    $graph->{$2}{$1} = 0 unless exists $graph->{$2}{$1};
    $graph->{$1}{$2}++;
    $graph->{$2}{$1}++;
}

close GRAPH;

#print "43 -- 61: ".get_sampled_hitting_time("43", "61", $graph, $NUM_SAMPLES)."\n";
#print "202 -- 208: ".get_sampled_hitting_time("202", "208", $graph, $NUM_SAMPLES)."\n";

my @aids = `cat $data_file | awk -F " ::: " '{print \$1}'`;
map(chomp($_), @aids);

for(my $i = 0; $i <= $#aids; $i++) {
    for(my $j = 0; $j <= $#aids; $j++) {
	next if $i == $j;
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
	my $ht = get_hitting_time($a1, $a2, $graph, 0);
	$aht += $ht;
    }

    return $aht/$num_samples;
}

sub get_hitting_time {
    my $source = shift;
    my $target = shift;
    my $graph = shift;
    my $iter = shift;

    while(1) {
	
#    print "$source -> ";

	if($source eq $target) {
#	print "FOUND [$target]\n";
	    return $iter;
	} 

#    print " {$iter} ";

	if($iter >= $MAX_ITER) {
#	print "FAIL_MAXED\n";
	    return $MAX_ITER;
	}

	my @potential_hops = keys %{$graph->{$source}};

	if($#potential_hops == -1) {
#	print "FAIL_NOHOP\n";
	    return $MAX_ITER;
	}

	my $hop_weights = {};
	foreach my $t (@potential_hops) {
	    $hop_weights->{$t} = $graph->{$source}{$t};
	}

	my $hop = pick_weighted_random($hop_weights);
	$source = $hop;
	$iter++;
    }

}

sub pick_weighted_random {
    my $hop_weights = shift;
    my $total = 0;
    my $dist = {};
    
    foreach (values %$hop_weights) {
        $total += $_;
    }

    while ( my ($key, $weight) = each %$hop_weights ) {
        $dist->{$key} = $weight/$total;
    }

    while (1) {                     # to avoid floating point inaccuracies
        my $rand = rand;
        while ( my ($key, $weight) = each %$dist ) {
            return $key if ($rand -= $weight) < 0;
        }
    }
    
}

#=======testing weighted random =====

# my $h = {50 => 1, 51 => 3, 52 => 2, 53 => 1, 54 => 1};
# my $cnts = {};
# my $total = 10000;

# for(my $i=0; $i< $total; $i++) {
#     my $p = pick_weighted_random($h);
#     $cnts->{$p} = 0 unless exists $cnts->{$p};
#     $cnts->{$p}++;
# }

# while( my ($k, $v) = each %$cnts)  {
#     printf "%s : %.2f\n", $k, $v/$total;
# }

#=======finish testing weighted random =====
