#!/usr/bin/perl

use strict;
use warnings;

use Storable qw(dclone);
use Data::Dumper;


my $key = shift;


my $graph_file = "./files/$key.graph";
my $data_file = "./files/$key.data";
my $output_paths = ">./files/$key.paths";

open GRAPH, $graph_file or die $!;

my $graph = {};
my $edge_pubs = {};

# read the undirected graph
while(<GRAPH>) {
    chomp($_);
    $_ =~ m/^(\d+) === (\d+) \((.*)\)$/g;
    $graph->{$1} = [] unless exists $graph->{$1};
    $graph->{$2} = [] unless exists $graph->{$2};
    push(@{$graph->{$1}}, $2);
    push(@{$graph->{$2}}, $1);
    
    # we assume the vertices for edges are always in increasing order, so only store one array per edge
    $edge_pubs->{"$1_$2"} = [] unless exists $edge_pubs->{$1."_".$2};
    push(@{$edge_pubs->{"$1_$2"}}, $3);
}

close GRAPH;

# read the ids
my @aids = `cat $data_file | awk -F " ::: " '{print \$1}'`;
map(chomp($_), @aids);

my @Q = ();
my %I = ();
my %source = ();
my %subpath = ();

my %aid_hash = ();
$aid_hash{$_} = 1 foreach @aids;

foreach my $r (@aids) {
    my $visited = {};
    my %step_calls = ();
    print "Starting with new r: $r\n";
    unshift(@Q, $r);
    while($#Q > -1) {
	print Dumper @Q;
	my $u = pop @Q;
	next if exists $visited->{$u};
	$visited->{$u} = 1;
        print "Popped $u\n";
	print "Adjacent nodes are: ";
	print $_." " foreach(@{$graph->{$u}});
	print "\n";
	foreach my $v (@{$graph->{$u}}) {
	    next if $v eq $r;
	    if(exists $aid_hash{$v}) {
		next;
	    }
	    next if exists $step_calls{$r."_".$v};
	    foreach my $s (@{step($r, $v, $graph)}) {
		$step_calls{$r."_".$v} = 1;
		my $slen = $#{$s};
		if($slen == 1) {
		    if(!(exists $I{$v})) {
			$I{$v} = 1;
		    }
		    
		    $source{$v} = [] unless exists $source{$v};
		    push(@{$source{$v}}, $r) unless in_array($source{$v}, $r);

		    $subpath{$r} = {} unless exists $subpath{$r};
		    my $subpath_str = join(" ", @$s);
		    print "Found ($subpath_str)\n";
		    $subpath{$r}{$subpath_str} = 1;
		    print "Pushed $v\n" unless exists $visited->{$v};
		    unshift(@Q, $v) unless exists $visited->{$v};
		} elsif($slen == 2) {
		    if(is_valid_2($s, $graph)) {
			if(!(exists $I{$v})) {
			    $I{$v} = 1;
			}

			$source{$v} = [] unless exists $source{$v};
			push(@{$source{$v}}, $r) unless in_array($source{$v}, $r);

			$subpath{$r} = {} unless exists $subpath{$r};
			my $subpath_str = join(" ", @$s);
			print "Found ($subpath_str)\n";
			if(!is_valid($subpath_str, $graph)) {
			    print "Invalid path: ($subpath_str)\n";
			} else {
			    $subpath{$r}{$subpath_str} = 1;
			}
		    }
		}
	    }
	}
    }
}

open PATHS, $output_paths or die $!;

foreach my $v (keys %I) {
    my @rs = @{$source{$v}};
    for(my $i = 0; $i <= $#rs; $i++) {
	for(my $j = $i+1; $j <= $#rs; $j++) {
	    next if $i == $j;
	    my $a1 = $rs[$i];
	    my $a2 = $rs[$j];

	    print "$v for $a1 and $a2\n";
	    foreach my $p1 ((grep {$_ =~ m/\s$v$/ } keys %{$subpath{$a1}})) { # subpaths ending in $v
		foreach my $p2 ((grep {$_ =~ m/\s$v$/ } keys %{$subpath{$a2}})) {
		    my @path1 = split(/\s+/, $p1);
		    my @path2 = split(/\s+/, $p2);
		    my $connector = "";
		    while($path1[$#path1] eq $path2[$#path2]) {
			$connector = $path1[$#path1];
			pop @path1;
			pop @path2;
		    }
		    my $newpath = join(" ", @path1)." $connector ".join(" ", reverse(@path2));
		    print $p1." + ".$p2." = $newpath\n";
		    if($a1 < $a2) {
			print PATHS "$a1 $a2 ($newpath)\n";
		    } else {
			print PATHS "$a2 $a1 ($newpath)\n";
		    }
		}
	    }
	}
    }
}

sub is_valid {
    my $path = shift;
    my $graph = shift;

    my @nodes = split(/\s+/, $path);
    my $init = 0;

    for(my $s = $init; $s + 2 <= $#nodes; ++$s) {
	my @curpath = @nodes[$s..($s+2)];
	if(!is_valid_2(\@curpath, $graph)) {
	    return 0;
	}
    }
    return 1;
}

sub is_valid_2 {
    my $path = shift;
    my $graph = shift;

    my ($s, $m, $e) = @$path;
    my $path1 = $s < $m ? "$s\_$m" : "$m\_$s";
    my $path2 = $m < $e ? "$m\_$e" : "$e\_$m";
    my $path3 = $s < $e ? "$s\_$e" : "$e\_$s";

    my $pub1 = $edge_pubs->{$path1};
    my $pub2 = $edge_pubs->{$path2};
    my $pub3 = $edge_pubs->{$path3};

    if(($#{$pub1} == 0 && $#{$pub2} == 0) && ($pub1->[0] eq $pub2->[0])) {
    	return 0;
    } elsif(($#{$pub2} == 0 && $#{$pub3} == 0) && ($pub2->[0] eq $pub3->[0])) {
    	return 0;
    }elsif(($#{$pub3} == 0 && $#{$pub1} == 0) && ($pub3->[0] eq $pub3->[0])) {
    	return 0;
    }else {
    	return 1;
    }
    return 1;
}

sub step {
    my $r = shift;
    my $v = shift;
    my $graph = shift;

    my @init_paths = ($r);
    print "Calling findpaths with $r and $v\n";
    return findpaths($v, $graph, \@init_paths, {});
}

sub findpaths {
    my $target = shift;
    my $graph = shift;
    my $cur_path = shift;
    my $visited = shift;
    
    my @ret_paths = ();

    my $len = @$cur_path;
    return \@ret_paths if $len > 2;
    
    my $cur_node = $cur_path->[$len-1];
    return @ret_paths if exists $visited->{$cur_node};
    $visited->{$cur_node} = 1;
#    print "Strting with $cur_node and will go to".Dumper($graph->{$cur_node})."\n";
    foreach my $next (@{dedup($graph->{$cur_node})}) {
	
	my @new_path = @$cur_path;
	push(@new_path, $next);
	if($next eq $target) {
	    push(@ret_paths, \@new_path);
	    next;
	}
	
#	print "Calling findpaths with $cur_node and $target\n";
	@ret_paths = (@ret_paths, @{findpaths($target, $graph, \@new_path, $visited)});
    }
    return \@ret_paths;
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
