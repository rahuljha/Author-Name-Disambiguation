#!/usr/bin/perl

use strict;
use warnings;

use Storable qw(dclone);
use Data::Dumper;

my $key = shift;
my $CUTOFF = shift;

my $graph_file = "./files/$key.graph";
my $data_file = "./files/$key.data";

open GRAPH, $graph_file or die $!;

my $orig_graph = {};
my $clusters = {};

my $MAX_ITER = 10;
my $NUM_SAMPLES = 1000;

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

foreach my $aid (keys %$orig_graph) {
    $orig_graph->{$aid} = dedup($orig_graph->{$aid});
}

# read the ids
my @aids = `cat $data_file | awk -F " ::: " '{print \$1}'`;
map(chomp($_), @aids);

my $cur_graph = dclone($orig_graph);
my $orig_aids = dclone(\@aids);

my $iterations = 1;
while(1) {
    print "iteration: $iterations with cutoff $CUTOFF\n";
    my $max_id = find_max_id($cur_graph, \@aids);
    my $htimes = {};
    my $found_clusters = 0;
    my $new_clusters = {};

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

    my @new_aids = @{dclone \@aids};

    open OUT_CTIMES, ">./files/$key.ctimes.$iterations" or die $!;
    for(my $i = 0; $i <= $#aids; $i++) {
	for(my $j = $i+1; $j <= $#aids; $j++) {
	    my $a1 = $aids[$i];
	    my $a2 = $aids[$j];
	    my $comm_time = $htimes->{$a1}{$a2} + $htimes->{$a2}{$a1};
	    print OUT_CTIMES "$a1 $a2 $comm_time\n";
	    if($comm_time < $CUTOFF) {
		# merge the nodes
		$found_clusters = 1;
		if(exists $new_clusters->{$a1} && exists $new_clusters->{$a2}) {
		    next if($new_clusters->{$a1} eq $new_clusters->{$a2});
		    #both were already assigned to new and different clusters in this iteration, merge them
		    my $old_cid = $new_clusters->{$a2};
		    while( my ($aid, $cid) = each %$new_clusters) {
			if($cid eq $old_cid) {
			    $new_clusters->{$aid} = $new_clusters->{$a1};
			}
		    }
		    @new_aids = remove_element($old_cid, @new_aids);
		} elsif(exists $new_clusters->{$a1}) {
		    # $a1 was assigned a cluster earlier in this iteration, add $a2 to the same cluster
		    $new_clusters->{$a2} = $new_clusters->{$a1};
		    @new_aids = remove_element($a2, @new_aids);
		} elsif(exists $new_clusters->{$a2}) {
		    # a2 was assigned a cluster earlier in this iteration , add $a1 to the same cluster
		    $new_clusters->{$a1} = $new_clusters->{$a2};
		    @new_aids = remove_element($a1, @new_aids);
		} else {
		    # both are original author ids, so create a new cluster id and assign to both
		    my $merged_id = ++$max_id;
		    $new_clusters->{$a1} = $merged_id;
		    $new_clusters->{$a2} = $merged_id;
		    @new_aids = remove_element($a1, @new_aids);
		    @new_aids = remove_element($a2, @new_aids);
		    push(@new_aids, $merged_id);
		}
	    }
	}
    }
    close OUT_CTIMES;
    
    last if($found_clusters == 0);
#    last if($CUTOFF >= 15);
#    $CUTOFF += 0.5;

    #merge the new clusters to earlier ones
    
    @aids = @new_aids;
    my %rev_old_clusters = reverse %$clusters;
    foreach my $k (keys %$new_clusters) {
	if(exists $rev_old_clusters{$k}) {
	    # this node was a cluster node
	    for my $n (keys %$clusters) {
		if($clusters->{$n} eq $k) {
		    $clusters->{$n} = $new_clusters->{$k};
		}
	    }
	} else {
	    $clusters->{$k} = $new_clusters->{$k};
	}
    }


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
	$cur_graph->{$s_new} = dedup($cur_graph->{$s_new});
    }

    print_clusters($iterations);
    $iterations++;
}

sub print_clusters {
    $iterations = shift;
    open OUT_CLUSTERS, ">./files/$key.clust.$iterations" or die $!;
# print out the clusters
    my $max_id = find_max_id($cur_graph, \@aids);

    foreach my $aid (@$orig_aids) {
	if(exists $clusters->{$aid}) {
	    print OUT_CLUSTERS "$aid ".$clusters->{$aid}."\n";
	} else {
	    print OUT_CLUSTERS "$aid ".++$max_id."\n";
	}
    }
    close OUT_CLUSTERS;
}

sub get_sampled_hitting_time {
    my $a1 = shift;
    my $a2 = shift;
    my $graph = shift;
    my $num_samples = shift;

    my $aht = 0;
    my $cnt = 0;
    for(my $i = 0; $i < $num_samples; $i++) {
	my $ht = get_hitting_time($a1, $a2, $graph, 0);
	$aht += $ht;
	# if($ht > 0) {
	#     $cnt++;
	#     $aht += $ht;
	# }
    }

    return $aht/$num_samples;
#    return $cnt > 0 ? $aht/$cnt : 100;
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
#	    return 0;
	}

	my $num_hops;
	my $potential_hops = $graph->{$source};
	if(! defined $potential_hops) {
	    $num_hops = 0;
	} else {
	    $num_hops = scalar(@{$potential_hops});
	}

	if($num_hops == 0) {
#	print "FAIL_NOHOP\n";
	    return $MAX_ITER;
#	    return 0;
	}


	my $hop = $potential_hops->[int(rand($num_hops))];

	$source = $hop;
	$iter++;
    }

}

sub remove_element {
    my $el = shift;
    my @arr = @_;

    if(!in_array(\@arr, $el)) {
	print "what?\n";
    }

    my $index = 0;
    $index++ until $arr[$index] eq $el;
    splice(@arr, $index, 1);
    return @arr;
}

sub find_max_id {
    my $graph = shift;
    my $aids = shift;
    my $max_id = 0;
    
    foreach my $s (keys %$graph) {
	foreach my $t (@{$graph->{$s}}) {
	    $max_id = $t if $t > $max_id;
	}
    }

    my @sorted_aids = reverse sort {$a <=> $b} @$aids;
    $max_id = $sorted_aids[0] if $sorted_aids[0] > $max_id;
    return $max_id;

}

# deduplicate while preserving order
sub dedup {
    my $in_array = shift;
    my @ret_array = ();
    
    my %hash   = map { $_ => 0 } @{$in_array};
    foreach(@$in_array) {
	push(@ret_array, $_) unless $hash{$_} == 1;
	$hash{$_} = 1
    }
    return \@ret_array;
}

sub in_array {
     my ($arr,$search_for) = @_;
    my %items = map {$_ => 1} @$arr; # create a hash out of the array values
    return (exists($items{$search_for}))?1:0;
}
