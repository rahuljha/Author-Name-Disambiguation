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
my $eval_dir = "/home/rahuljha/author_name_normalization/evaluation_data";
my %id_hash = ();

my $aff_shingles = {};
my $aff_strings = {};
my $aff_links = {};

my $email_ids = {};
my $key = shift;


open GOLD, ">$BASE_DIR/$key.fullgold" or die $!;
open GRAPH, ">$BASE_DIR/$key.fullgraph" or die $!;
open DATA, ">$BASE_DIR/$key.fulldata" or die $!;
open AFFS, ">$BASE_DIR/$key.fullaffids" or die $!;
open EMAILS, ">$BASE_DIR/$key.fullemailids" or die $!;

open READ_FILE, "$eval_dir/$key.txt" or die $!;

my $cnt = 1;
my $aff_cnt = 1;

while(<READ_FILE>) {
    my $curauth_id = $cnt;
    $cnt++;

    if($curauth_id eq "1206") {
	print "came here";
    }

    print DATA "$curauth_id ::: $_";
    chomp($_);
    my ($cid, $curauth, $pid, $t2, $t3, $email, $aff) = split(/ ::: /, $_);

    print GOLD "$curauth_id $cid\n";

    # assign id to affiliation
    if(defined $aff && $aff ne "") {
	my $cur_aff_id = $aff_cnt;
	$aff_cnt++;
	$aff_shingles->{$cur_aff_id} = get_shingles($aff);
	$aff_links->{$curauth_id} = $cur_aff_id;
	$aff_strings->{$cur_aff_id} = $aff;
    }

    # link to email id
    if(defined $email && $email ne "") {
	my $cur_email_id = "";
	if(exists $email_ids->{$email}) {
	    $cur_email_id = $email_ids->{$email};
	} else {
	    $cur_email_id = $cnt;
	    $cnt++;
	    $email_ids->{$email} = $cur_email_id;
	    print EMAILS "$email $cur_email_id\n";
	}

	print GRAPH "$curauth_id === $cur_email_id\n";
    }
    
    # add coauthors 
    my $co_author_entries = `cat $all_authors | grep ^$pid`;
    my @co_author_strs = split(/\n/, $co_author_entries);
    foreach my $co_author_str (@co_author_strs) {
	my ($pid, $lname, $fname, $email, $aff) = split(/ ::: /, $co_author_str);
	# add coauthor edge
	my $norm_coauth = get_normalized_author($lname, $fname);
	next if $norm_coauth eq $curauth;
	my $coauth_id = '';
	if(exists $id_hash{$norm_coauth}) {
	    $coauth_id = $id_hash{$norm_coauth};
	} else {
	    $coauth_id = $cnt;
	    $cnt++;
	}
	$id_hash{$norm_coauth} = $coauth_id;
	print GRAPH "$curauth_id === $coauth_id\n";

	# # add coauthor affiliations
	# if(defined $aff && $aff ne "") {
	#     my $cur_aff_id = $aff_cnt;
	#     $aff_cnt++;
	#     $aff_shingles->{$cur_aff_id} = get_shingles($aff);
	#     $aff_links->{$coauth_id} = $cur_aff_id;
	#     $aff_strings->{$cur_aff_id} = $aff;
	# }

	# # link to email id
	# if(defined $email && $email ne "") {
	#     my $cur_email_id = "";
	#     if(exists $email_ids->{$email}) {
	# 	$cur_email_id = $email_ids->{$email};
	#     } else {
	# 	$cur_email_id = $cnt;
	# 	$cnt++;
	# 	$email_ids->{$email} = $cur_email_id;
	# 	print EMAILS "$email $cur_email_id\n";
	#     }
	#     print GRAPH "$coauth_id === $cur_email_id\n";
	# }
    }  
}

# merge affiliation nodes based on shingling
my @tmp_aff_ids = keys %$aff_shingles;
my $tmp2real_aff = {};

for(my $i = 0; $i <= $#tmp_aff_ids; $i++) {
    for(my $j = $i+1; $j <= $#tmp_aff_ids; $j++) {
	my $aff1 = $tmp_aff_ids[$i];
	my $aff2 = $tmp_aff_ids[$j];

	my $jc = get_jaccard_coeff($aff_shingles->{$aff1}, $aff_shingles->{$aff2});

	my ($real_id_1, $real_id_2);
	if(exists $tmp2real_aff->{$aff1}) {
	    $real_id_1 = $tmp2real_aff->{$aff1};
	} else {
	    $real_id_1 = $cnt;
	    $cnt++;
	    $tmp2real_aff->{$aff1} = $real_id_1;
	}

	if($jc > $JC_CUTOFF) {
	    $real_id_2 = $real_id_1;
	    $tmp2real_aff->{$aff2} = $real_id_2;
	} elsif(!exists $tmp2real_aff->{$aff2}) {
	    $real_id_2 = $cnt;
	    $cnt++;
	    $tmp2real_aff->{$aff2} = $real_id_2;
	}
    }
}

# print aff nodes now
foreach my $a (keys %$aff_links) {
    my $tmp_aff = $aff_links->{$a};
    print GRAPH "$a === ".$tmp2real_aff->{$tmp_aff}."\n";
}

foreach my $taid (keys %$aff_strings) {
    print AFFS $tmp2real_aff->{$taid}." ::: ".$aff_strings->{$taid}."\n";
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
