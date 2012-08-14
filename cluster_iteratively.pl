#!/usr/bin/perl

use strict;
use warnings;

use Storable qw(dclone);;

my $graph_file = shift;
my $data_file = shift;

open GRAPH, $graph_file or die $!;

my $orig_graph = {};
my $clusters = {};

my $MAX_ITER = 10;
my $NUM_SAMPLES = 100;

# read the undirected graph
while(<GRAPH>) {
    chomp($_);
    $_ =~ m/^(\d+) === (\d+)$/g;
    $orig_graph->{$1} = [] unless exists $orig_graph->{$1};
    $orig_graph->{$2} = [] unless exists $orig_graph->{$2};
    push(@{$orig_graph->{$1}}, $2);
    push(@{$orig_graph->{$2}}, $1);
}

close GRAPH;

# read the ids
my @aids = `cat $data_file | awk -F " ::: " '{print \$1}'`;
map(chomp($_), @aids);

my $cur_graph = dclone($orig_graph);
my $orig_aids = dclone(\@aids);

while(1) {
    my $max_id = find_max_id($cur_graph);
    my $htimes = {};
    my $new_clusts = 0;

    for(my $i = 0; $i <= $#aids; $i++) {
	for(my $j = 0; $j <= $#aids; $j++) {
	    next if ($i == $j);
	    my $a1 = $aids[$i];
	    my $a2 = $aids[$j];

	    $htimes->{$a1} = {} unless exists $htimes->{$a1};
	    my $ht = get_sampled_hitting_time($a1, $a2, $cur_graph, $NUM_SAMPLES);
	    $htimes->{$a1}{$a2} = $ht;
	}
    }

    my %rev_clusters = reverse %$clusters;

    my @new_aids = @{dclone \@aids};
    for(my $i = 0; $i <= $#aids; $i++) {
	for(my $j = $i+1; $j <= $#aids; $j++) {
	    my $a1 = $aids[$i];
	    my $a2 = $aids[$j];
	    my $comm_time = $htimes->{$a1}{$a2} + $htimes->{$a2}{$a1};
	    if($comm_time < 11) {
		$new_clusts++;
		# merge the nodes
		if(exists $rev_clusters{$a1}) { 
		    # this means $a1 already is a cluster
		    $clusters->{$a2} = $a1;
		    @new_aids = remove_element($a2, @new_aids);
		} elsif(exists $rev_clusters{$a2}) {
		    # this means $a2 already is a cluster
		    $clusters->{$a1} = $a2;
		    @new_aids = remove_element($a1, @new_aids);
		} else {
		    # both are original author ids, so create a new cluster id and assign to both
		    my $merged_id = ++$max_id;
		    $clusters->{$a1} = $merged_id;
		    $clusters->{$a2} = $merged_id;
		    @new_aids = remove_element($a1, @new_aids);
		    @new_aids = remove_element($a2, @new_aids);
		    push(@new_aids, $merged_id);
		}
	    }
	}
    }
    
    last if($new_clusts == 0);


    @aids = @new_aids;

    # create new graph 
    $cur_graph = {};

    foreach my $s (keys %$orig_graph) {
	my $s_new = (exists $clusters->{$s}) ? $clusters->{$s} : $s;
	my $targets = $orig_graph->{$s};
	$cur_graph->{$s_new} = [] unless exists $cur_graph->{$s_new};
	foreach my $t (@$targets) {
	    my $t_new = (exists $clusters->{$t}) ? $clusters->{$t} : $t;
	    push(@{$cur_graph->{$s_new}}, $t_new);
	}
    }
}

# print out the clusters
my $max_id = find_max_id($cur_graph);

foreach my $aid (@$orig_aids) {
    if(exists $clusters->{$aid}) {
	print "$aid ".$clusters->{$aid}."\n";
    } else {
	print "$aid ".++$max_id."\n";
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

	my $potential_hops = $graph->{$source};
	my $num_hops = scalar(@{$potential_hops});

	if($num_hops == 0) {
#	print "FAIL_NOHOP\n";
	    return $MAX_ITER;
	}


	my $hop = $potential_hops->[int(rand($num_hops))];

	$source = $hop;
	$iter++;
    }

}

sub remove_element {
    my $el = shift;
    my @arr = @_;

    my $index = 0;
    $index++ until $arr[$index] eq $el;
    splice(@arr, $index, 1);
    return @arr;
}

sub find_max_id {
    my $graph = shift;

    my $max_id = 0;
    
    foreach my $s (keys %$graph) {
	foreach my $t (@{$graph->{$s}}) {
	    $max_id = $t if $t > $max_id;
	}
    }
    return $max_id;

}
