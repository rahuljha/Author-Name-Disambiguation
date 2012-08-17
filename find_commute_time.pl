#!/usr/bin/perl

use strict;
use warnings;

my $debug = 0;

my $graph_file = shift;
my $data_file = shift;

open GRAPH, $graph_file or die $!;

my $graph = {};

my $MAX_ITER = 10;
my $NUM_SAMPLES = 100;

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
my $htimes = {};

for(my $i = 0; $i <= $#aids; $i++) {
    for(my $j = 0; $j <= $#aids; $j++) {
	next if ($i == $j);
	$htimes->{$aids[$i]} = {} unless exists $htimes->{$aids[$i]};
	my $ht = get_sampled_hitting_time($aids[$i], $aids[$j], $graph, $NUM_SAMPLES);
	$htimes->{$aids[$i]}{$aids[$j]} = $ht;
    }
}

for(my $i = 0; $i <= $#aids; $i++) {
    for(my $j = $i+1; $j <= $#aids; $j++) {
	my $a1 = $aids[$i];
	my $a2 = $aids[$j];
	print $a1." ".$a2." ".($htimes->{$a1}{$a2} + $htimes->{$a2}{$a1})."\n";
    }
}

sub get_sampled_hitting_time {
    my $a1 = shift;
    my $a2 = shift;
    my $graph = shift;
    my $num_samples = shift;

    my $aht = 0;
#    my $cnt = 0;
    for(my $i = 0; $i < $num_samples; $i++) {
	my $ht = get_hitting_time($a1, $a2, $graph, 0);
	# if($ht > 0) {
	#     $aht += $ht;
	#     $cnt++;
	# }
    }

    return $aht/$num_samples;
#    return $aht/$cnt;
}

sub get_hitting_time {
    my $source = shift;
    my $target = shift;
    my $graph = shift;
    my $iter = shift;

    while(1) {
	
    print "$source -> " if $debug;

	if($source eq $target) {
	print "FOUND [$target]\n" if $debug;
	    return $iter;
	} 

    print " {$iter} " if $debug;

	if($iter >= $MAX_ITER) {
	    print "FAIL_MAXED\n" if $debug;
	    return $MAX_ITER;
#	    return 0;
	}

	my @potential_hops = keys %{$graph->{$source}};

	if($#potential_hops == -1) {
	    print "FAIL_NOHOP\n" if $debug;
	    return $MAX_ITER;
#	    return 0;
	}

	# my $hop_weights = {};
	# foreach my $t (@potential_hops) {
	#     $hop_weights->{$t} = $graph->{$source}{$t};
	# }

	my $num_hops = scalar(@potential_hops);
	my $hop = $potential_hops[int(rand($num_hops))];

	$source = $hop;
	$iter++;
    }

}

my $weight_store = {};
my $rndselect_store = {};

sub pick_weighted_random {
    my $aid = shift;
    my $buckets = shift;

    my $weighttotal  = 0;
    my $rndselect = [];

    if(exists $weight_store->{$aid} && exists $rndselect_store->{$aid}) {
	$weighttotal = $weight_store->{$aid};
	$rndselect = $rndselect_store->{$aid};
    } else {
	my $group = { %$buckets };
	
	foreach my $advert ( keys %$group ) {
	    $weighttotal += $group->{$advert};
	    while ( $group->{$advert} > 0 ) {
		push( @$rndselect, $advert );
		$group->{$advert}--;
	    }#while
	}#loop

	$weight_store->{$aid} = $weighttotal;
	$rndselect_store->{$aid} = $rndselect;
    }

    my $rannum = rand($weighttotal);
    $rannum  = int($rannum);
    return($rndselect->[$rannum]);
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
