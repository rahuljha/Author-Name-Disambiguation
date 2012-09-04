#!/usr/bin/perl

use strict;
use warnings;

use utf8;
use Text::Unidecode;
use HTML::Entities;

my $K = 3;
my $JC_CUTOFF = .5;

my $BASE_DIR = "./files";
# Read evaluation file for a single cluster and create complete graph
# Print out in edge-edge format
my $eval_dir = "/data0/projects/fuse/author_disambiguation/evaluation_data/Giles_DBLP/";
my %id_hash = ();

my $key = shift;
my $full_coauth = shift;
$full_coauth = "false" if !defined $full_coauth;

open GOLD, ">$BASE_DIR/$key.gold" or die $!;
open GRAPH, ">$BASE_DIR/$key.graph" or die $!;
open DATA, ">$BASE_DIR/$key.data" or die $!;
open CAIDS, ">$BASE_DIR/$key.caids" or die $!;

open READ_FILE, "$eval_dir/$key.txt" or die $!;

my $cnt = 1;

my %seen_titles = ();

while(<READ_FILE>) {
    my $curauth_id = $cnt;
   $cnt++;

    chomp($_);
    $_ = unidecode(decode_entities($_));

    my ($auths, $title, $venue) = split(/<>/, $_);

    $seen_titles{norm_title($title)} = 1;

    $auths =~ m/(\d+)_(\d+)\s*(.*)$/;
    my $cid = $1;
    my $paper_id = "$1_$2";
    my @coauthor_strs = split(/;/, $3);

    if($#coauthor_strs == 0) {
	print "$_\n";
	next;
    }

    print DATA "$curauth_id ::: $_\n";
    print GOLD "$curauth_id $cid\n";

    # add coauthors 
    my $cur_coauths = {};
#    print "\n$curauth_id ::: ";
     foreach my $co_author_str (@coauthor_strs) {
	 $co_author_str =~ s/^\s+//;
	 $co_author_str =~ s/\s+$//;

	 next if $co_author_str eq "";

	 my @nameparts = split(/\s+/, $co_author_str);
	 my @fnames = @nameparts[0..($#nameparts-1)];
	 my $lname = $nameparts[$#nameparts];
	 
	 my $fname = "";
	 $fname = $fname." ".$_ foreach(@fnames);

 	# add coauthor edge    
	 my $norm_coauth = get_normalized_author($lname, $fname);
	 my $norm_coauth_2 = get_normalized_author_2($lname, $fname);
#	 print "$co_author_str: $norm_coauth\n";

	 next if ($norm_coauth eq $key || $norm_coauth_2 eq $key);

	 my $coauth_id = '';
	 $co_author_str =~ s/[[:punct:]\d]//g;
	 my $co_author_str = lc(unidecode($co_author_str));

	 if(exists $id_hash{$norm_coauth}) {
	     $coauth_id = $id_hash{$norm_coauth};
	 } else {
	     $coauth_id = $cnt;
	     $cnt++;
	     print CAIDS "$coauth_id $norm_coauth\n";
	     $id_hash{$norm_coauth} = $coauth_id;
	 }
#	 print " ($coauth_id  '$co_author_str')\n";
	 my $edge_str = ($curauth_id < $coauth_id) ? "$curauth_id === $coauth_id ($paper_id)\n" : "$coauth_id === $curauth_id ($paper_id)\n";
	     
	 print GRAPH $edge_str;
	 $cur_coauths->{$coauth_id} = 1;
    }  

    my @coauth_ids = sort {$a <=> $b} keys %$cur_coauths;
    for(my $i = 0; $i <= $#coauth_ids; $i++) {
    	for(my $j = $i+1; $j <= $#coauth_ids; $j++) {
	    my $ci = $coauth_ids[$i];
	    my $cj = $coauth_ids[$j];
	    my $edge_str = ($ci < $cj) ? "$ci === $cj ($paper_id)\n" : "$cj === $ci ($paper_id)\n";
    	    print GRAPH $edge_str;
    	}
    }
}

# now add other co-authors 
if($full_coauth eq "true") {
    open COAUTH, "/data0/projects/fuse/author_disambiguation/algorithms/fan_dblp_all_coauths/$key.txt" or die $!;
    while(<COAUTH>) {
	my $cur_coauths = {};
	chomp($_);
	my ($paper_id, $coauths, $title) = split(/<>/, $_);
	$coauths =~ s/\d+//; # because some of them have digits!
	$paper_id = "dblp_".$paper_id;
	if(exists $seen_titles{norm_title($title)}) {
	    print "Found a seen title ".$title."\n";
	    next;
	}
	my @coauthor_strs = split(/;/, $coauths);

	foreach my $co_author_str (@coauthor_strs) {
	    $co_author_str =~ s/^\s+//;
	    $co_author_str =~ s/\s+$//;
    
	    next if $co_author_str eq "";

	    my @nameparts = split(/\s+/, $co_author_str);
	    my @fnames = @nameparts[0..($#nameparts-1)];
	    my $lname = $nameparts[$#nameparts];
	    
	    my $fname = "";
	    $fname = $fname." ".$_ foreach(@fnames);

	    # add coauthor edge    
	    my $norm_coauth = get_normalized_author($lname, $fname);
	    print "$co_author_str: $norm_coauth\n";

	    next if ($norm_coauth eq $key);

	    my $coauth_id = '';
	    $co_author_str =~ s/[[:punct:]\d]//g;
	    my $co_author_str = lc(unidecode($co_author_str));
	    
	    if(exists $id_hash{$norm_coauth}) {
		$coauth_id = $id_hash{$norm_coauth};
	    } else {
		$coauth_id = $cnt;
		$cnt++;
		$id_hash{$norm_coauth} = $coauth_id;
		print CAIDS "$coauth_id $norm_coauth\n";
	    }
	    $cur_coauths->{$coauth_id} = 1;
	}

	my @coauth_ids = sort {$a <=> $b} keys %$cur_coauths;
	for(my $i = 0; $i <= $#coauth_ids; $i++) {
	    for(my $j = $i+1; $j <= $#coauth_ids; $j++) {
		my $ci = $coauth_ids[$i];
		my $cj = $coauth_ids[$j];
		my $edge_str = ($ci < $cj) ? "$ci === $cj ($paper_id)\n" : "$cj === $ci ($paper_id)\n";
		print GRAPH $edge_str;
	    }
	}
    }
}


sub get_normalized_author {
    my $lname = shift;
    my $fname = shift;

    $fname =~ s/^\s+//;
    $fname =~ s/\s+$//;
    $lname =~ s/^\s+//;
    $lname =~ s/\s+$//;

    # if($lname =~ m/(.*)\s+([^\s]+)$/) {
    # 	$lname = $2;
    # 	$fname = $fname." ".$1;
    # }
    
    $lname =~ s/-/ /g;
    $lname =~ s/\s+//g;

    $fname = "" unless defined $fname;
    $fname =~ s/-/ /g;

    my @fname_arr = split(/\s+/, $fname);

    my $out = $lname;
    
    if($#fname_arr > -1){
	for(my $i = $#fname_arr; $i >= 0; $i--) {
#	    if($i == 0) { 
#		$out = $fname_arr[$i].$out;
#	    } else {
#	    $out = substr($fname_arr[$i], 0, 1).$out;
	    $out = $fname_arr[$i].$out;
#	    }
	}
    }

    return lc($out);
}

sub get_normalized_author_2 {
    my $lname = shift;
    my $fname = shift;

    $fname =~ s/^\s+//;
    $fname =~ s/\s+$//;
    $lname =~ s/^\s+//;
    $lname =~ s/\s+$//;

    # if($lname =~ m/(.*)\s+([^\s]+)$/) {
    # 	$lname = $2;
    # 	$fname = $fname." ".$1;
    # }
    
    $lname =~ s/-/ /g;
    $lname =~ s/\s+//g;

    $fname = "" unless defined $fname;
    $fname =~ s/-/ /g;

    my @fname_arr = split(/\s+/, $fname);

    my $out = $lname;
    
    if($#fname_arr > -1){
#	for(my $i = $#fname_arr; $i >= 0; $i--) {
#	    if($i == 0) { 
#		$out = $fname_arr[$i].$out;
#	    } else {
#	    $out = substr($fname_arr[$i], 0, 1).$out;
	    $out = $fname_arr[0].$out;
#	    }
#	}
    }

    return lc($out);
}

sub norm_title {
    my $title = shift;
    $title = unidecode($title);
    $title =~ s/[[:punct:]\d]//g;
    $title = lc($title);
    $title =~ s/\s+//g;
    return $title;
}
