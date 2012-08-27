#!/usr/bin/perl

use strict;
use warnings;

use Storable qw(dclone);
use Data::Dumper;


my $key = shift;


my $data_file = "./files/$key.data";
my $paths_file = "./files/$key.paths";
my $id_map_file = "./files/$key.idmap";

my $sims_file = "./files/$key.sims";

open PATHS, $paths_file or die $!;

my $paths = {};
while(<PATHS>) {
    chomp($_);
    $_ =~ m/^(\d+)\s+(\d+)\s+(.*)$/;
    my $a1 = $1;
    my $a2 = $2;
    my $path = $3;
    $path =~ s/[\(\)]//g;
    $paths->{$a1} = {} unless exists $paths->{$a1};
    $paths->{$a1}{$a2} = [] unless exists $paths->{$a1}{$a2};
    push(@{$paths->{$a1}{$a2}}, $path) unless in_array($paths->{$a1}{$a2}, $path);
}



# read the ids
my @aids = `cat $data_file | awk -F " ::: " '{print \$1}'`;
map(chomp($_), @aids);

@aids = sort {$a <=> $b} @aids; # just in case

open ID_MAP, ">$id_map_file" or die $!;
my $idx = 1;
my %id_map = ();
foreach my $aid (@aids) {
    $id_map{$aid} = $idx;
    print ID_MAP "$aid $idx\n";
    $idx++;
}

open SIMS, ">".$sims_file or die $!;

my @sims = ();

for(my $i = 0; $i <= $#aids; $i++) {
    for(my $j = $i+1; $j <= $#aids; $j++) {
	my $a1 = $aids[$i];
	my $a2 = $aids[$j];

	my $paths = $paths->{$a1}{$a2};
	my $id1 = $id_map{$a1};
	my $id2 = $id_map{$a2};

	if(!defined $paths) { 
	    push(@sims, -10);
	    print SIMS "$id1 $id2 -10\n";
	} else {
	    my $sim = compute_sim($paths);
	    print SIMS "$id1 $id2 ".$sim."\n"; 
	    push(@sims, $sim);
	}
    }
}


sub compute_sim {
    my $paths = shift;
    my $alpha = 2.1;

    my $sum = 0.0;
    foreach my $p (@$paths) {
	my $len = split(/\s+/, $p);
	$len -= 2; # length to be used is the number of intermediate nodes along the path
	$sum += 1/($alpha ** ($len - 1));
    }

    return -1/$sum;
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
