#!/usr/bin/perl

use strict;
use warnings;

use Storable qw(dclone);;

my $key = shift;
my $CUTOFF = shift;

my $graph_file = "./files/$key.graph";
my $data_file = "./files/$key.data";

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
    print "iteration: $iterations\n";
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

    my @new_aids = @{dclone \@aids};
    my $merged_clusters = {};

    for(my $i = 0; $i <= $#aids; $i++) {
	for(my $j = $i+1; $j <= $#aids; $j++) {
	    my $a1 = $aids[$i];
	    my $a2 = $aids[$j];
	    my $comm_time = $htimes->{$a1}{$a2} + $htimes->{$a2}{$a1};
	    if($comm_time < $CUTOFF) {
		# keep a hash of current clusters
		my %rev_clusters = reverse %$clusters; 

		# first check if both nodes have already been merged earlier in this iteration
		# next if(!in_array(\@new_aids, $a1) && !in_array(\@new_aids, $a2));

		# else merge the nodes
		$new_clusts++;
		if(exists $rev_clusters{$a1} && exists $rev_clusters{$a2}) {
		    # this means both $a1 and $a2 are clusters
		    foreach my $a (keys %$clusters) {
			if($clusters->{$a} eq $a2) {
			    $clusters->{$a} = $a1;
			}
		    }
		    if(!in_array(\@new_aids, $a2)) {
			print "chk1";
		    }
		    $merged_clusters->{$a2} = $a1;
		    @new_aids = remove_element($a2, @new_aids);
		} elsif(exists $rev_clusters{$a1}) { 
		    # this means $a1 already is a cluster
		    if(exists $clusters->{$a2}) {
			# but a2 could already have been assigned a cluster in this iteration, if yes, merge that cluster into current $a1
			my $old_cid = $clusters->{$a2};
			while( my ($aid, $cid) = each %$clusters) {
			    if($cid eq $old_cid) {
				$clusters->{$aid} = $a1;
			    }
			}
			if(!in_array(\@new_aids, $old_cid)) {
			    print "chk2a";
			}
			$merged_clusters->{$old_cid} = $a1;
			@new_aids = remove_element($old_cid, @new_aids);
		    } else {
			$clusters->{$a2} = $a1;
			if(!in_array(\@new_aids, $a2)) {
			    print "chk2";
			}
			@new_aids = remove_element($a2, @new_aids);
		    }
		} elsif(exists $rev_clusters{$a2}) {
		    # this means $a2 already is a cluster
		    if(exists $clusters->{$a1}) {
			# but a1 could already have been assigned a cluster in this iteration, if yes, merge that cluster into current $a2
			my $old_cid = $clusters->{$a1};
			while( my ($aid, $cid) = each %$clusters) {
			    if($cid eq $old_cid) {
				$clusters->{$aid} = $a2;
			    }
			}
			if(!in_array(\@new_aids, $old_cid)) {
			    print "chk3a";
			}
			$merged_clusters->{$old_cid} = $a1;
			@new_aids = remove_element($old_cid, @new_aids);
		    } else {
			$clusters->{$a1} = $a2;
			if(!in_array(\@new_aids, $a1)) {
			    print "chk3";
			}
			@new_aids = remove_element($a1, @new_aids);
		    }
		} elsif(exists $clusters->{$a1} && exists $clusters->{$a2}) {
		    #both are already assigned to clusters, merge them
		    my $old_cid = $clusters->{$a2};
		    while( my ($aid, $cid) = each %$clusters) {
			if($cid eq $old_cid) {
			    $clusters->{$aid} = $a1;
			}
		    }
		    $merged_clusters->{$old_cid} = $a1;
		    @new_aids = remove_element($old_cid, @new_aids);
		} elsif(exists $clusters->{$a1}) {
		    # this means $a1 was assigned a cluster earlier in this iteration 
		    $clusters->{$a2} = $clusters->{$a1};
		    if(!in_array(\@new_aids, $a2)) {
			print "chk4";
		    }
		    @new_aids = remove_element($a2, @new_aids);
		} elsif(exists $clusters->{$a2}) {
		    # this means $a2 was assigned a cluster earlier in this iteration 
		    $clusters->{$a1} = $clusters->{$a2};
		    if(!in_array(\@new_aids, $a1)) {
			print "chk5";
		    }
		    @new_aids = remove_element($a1, @new_aids);
		}else {
		    # one of these might be an earlier cluster id that was reassigned
		    if(!in_array(\@new_aids, $a1) && exists $merged_clusters->{$a1})  {
			my $new_cid = $a1;
			while(exists $merged_clusters->{$new_cid}) {
			    $new_cid = $merged_clusters->{$new_cid};
			}
			$clusters->{$a2} = $new_cid;
			@new_aids = remove_element($a2, @new_aids);
		    } elsif(!in_array(\@new_aids, $a2) && exists $merged_clusters->{$a2})  {
			my $new_cid = $a2;
			while(exists $merged_clusters->{$new_cid}) {
			    $new_cid = $merged_clusters->{$new_cid};
			}
			$clusters->{$a1} = $new_cid;
			@new_aids = remove_element($a1, @new_aids);
		    } else {
			# both are original author ids, so create a new cluster id and assign to both
			my $merged_id = ++$max_id;
			$clusters->{$a1} = $merged_id;
			$clusters->{$a2} = $merged_id;
			if(!in_array(\@new_aids, $a1) || !in_array(\@new_aids, $a2)) {
			    print "chk6";
			}
			@new_aids = remove_element($a1, @new_aids);
			@new_aids = remove_element($a2, @new_aids);
			push(@new_aids, $merged_id);
		    }
		}

	    }
	}
    }
    
    last if($new_clusts == 0);
    $CUTOFF++;

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
	$cur_graph->{$s_new} = dedup($cur_graph->{$s_new});
    }

    print_clusters($iterations);
    $iterations++;
}

sub print_clusters {
    $iterations = shift;
    open OUT_CLUSTERS, ">./files/$key.clust.$iterations" or die $!;

# print out the clusters
    my $max_id = find_max_id($cur_graph);

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
    my $max_id = 0;
    
    foreach my $s (keys %$graph) {
	foreach my $t (@{$graph->{$s}}) {
	    $max_id = $t if $t > $max_id;
	}
    }
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
