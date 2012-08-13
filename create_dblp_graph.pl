#!/usr/bin/perl

use strict;
use warnings;

use utf8;
use Text::Unidecode;

my $K = 3;
my $JC_CUTOFF = .5;

my $BASE_DIR = "./files";
# Read evaluation file for a single cluster and create complete graph
# Print out in edge-edge format
my $all_authors = "/home/rahuljha/author_name_normalization/OA_authors.txt";
my $eval_dir = "/home/rahuljha/author_name_normalization/evaluation_data/Giles_DBLP/";
my %id_hash = ();

my $aff_shingles = {};
my $aff_strings = {};
my $aff_links = {};

my $email_ids = {};
my $key = shift;


open GOLD, ">$BASE_DIR/$key.gold" or die $!;
open GRAPH, ">$BASE_DIR/$key.graph" or die $!;
open DATA, ">$BASE_DIR/$key.data" or die $!;

open READ_FILE, "$eval_dir/$key.txt" or die $!;

my $cnt = 1;
my $aff_cnt = 1;

while(<READ_FILE>) {
    my $curauth_id = $cnt;
    $cnt++;

    print DATA "$curauth_id ::: $_";
    chomp($_);
    my ($auths, $title, $venue) = split(/<>/, $_);

    $auths =~ m/(\d+)_(\d+)\s*(.*)$/;
    my $cid = $1;
    my @coauthor_strs = split(/;/, $3);
    print GOLD "$curauth_id $cid\n";

    # add coauthors 
     foreach my $co_author_str (@coauthor_strs) {
	 $co_author_str =~ s/^\s+//;
	 $co_author_str =~ s/\s+$//;
	 $co_author_str =~ m/(.*)\s+([a-zA-Z]+)$/;
	 my $fname = $1;
	 my $lname = $2;
 	# add coauthor edge
	 my $norm_coauth = get_normalized_author($lname, $fname);
	 next if ($norm_coauth eq $key);
	my $coauth_id = '';
	if(exists $id_hash{$norm_coauth}) {
	    $coauth_id = $id_hash{$norm_coauth};
	} else {
	    $coauth_id = $cnt;
	    $cnt++;
	}
	$id_hash{$norm_coauth} = $coauth_id;
	print GRAPH "$curauth_id === $coauth_id\n";

    }  
}

sub get_normalized_author {
    my $lname = shift;
    my $fname = shift;

    $fname = "" unless defined $fname;

    $fname =~ s/-/ /g;
    my @fname_arr = split(/\s+/, $fname);

    my $out = $lname;

    foreach my $p (@fname_arr) {
	$out = substr($p, 0, 1).$out;
    }
    return lc($out);
}



sub get_shingles {
    my $aff = shift;
    my $n = $K; # size of shingles

    my $aff_str = unidecode($aff);
    unless(!(defined $aff_str) || $aff_str eq "") {
	$aff_str =~ s/[[:punct:]\d]//g;
    }

    $aff_str = lc($aff_str);

    my $shingle_store = {};

    my @words = split(/\s+/, $aff_str);
    
    for(my $i = 0; $i <= ($#words - $n + 1); $i++) {
	my $shingle = join(" ", @words[$i..$i+$n-1]);
	$shingle_store->{$shingle} = 1;
    }

    return $shingle_store;
}

sub get_jaccard_coeff {
    my $s1 = shift;
    my $s2 = shift;

    my $union_hash = {};

    my $intersect = 0;

    foreach my $s (keys %$s1) {
	if(exists $s2->{$s}) {
	    $intersect++;
	}
	$union_hash->{$s} = 1;
    }

    foreach my $s (keys %$s2) {
	$union_hash->{$s} = 1;
    }

    my $union_count = keys %$union_hash;
    return ($union_count == 0) ? 0 : $intersect/$union_count;

}
