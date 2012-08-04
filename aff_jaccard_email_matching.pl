#!/usr/bin/perl

use strict;
use warnings;

use utf8;
use Text::Unidecode;

# reads in a data file
# matches authors according to affiliations
# outputs the clusters

my $aff_shingles = {};

my $emails = {};

my $stop_words = load_stop_words();

while(<>) {
    chomp($_);
    my ($aid, $cid, $curauth, $pid, $t2, $t3, $email, $aff) = split(/ ::: /, $_);

    if((defined $email) && $email ne "") {
	$emails->{$aid} = $email;
    }

    my $aff_str = unidecode($aff);
    #TODO: remove affiliation stop words
    unless(!(defined $aff_str) || $aff_str eq "") {
	$aff_str =~ s/[[:punct:]\d]//g;
    }

    $aff_str = lc($aff_str);
#    $aff_str = remove_stop_words($aff_str);
    $aff_shingles->{$aid} = get_shingles($aff_str, 3);
}

my @aids = keys %$aff_shingles;

my $cnt = 1;
my %cids = ();

for(my $i = 0; $i <= $#aids; $i++) {
    for(my $j = $i+1; $j <= $#aids; $j++) {
	my ($id1, $id2);
	my $a1 = $aids[$i];
	my $a2 = $aids[$j];
	if(exists $cids{$a1}) {
	    $id1 = $cids{$a1};
	}else {
	    $id1 = $cnt;
	    $cnt++;
	    $cids{$a1} = $id1;
	}

	my $jc = get_jaccard_coeff($aff_shingles->{$a1}, $aff_shingles->{$a2});

	my $email_match = 0;
	if((exists $emails->{$a1} && exists $emails->{$a2}) && ($emails->{$a1} eq $emails->{$a2})) {
	    $email_match = 1;
	} 

	if($email_match || $jc > .6) {
	    $id2 = $id1;
	    $cids{$a2} = $id2;
	} elsif(!exists $cids{$a2}) {
	    $id2 = $cnt;
	    $cnt++;
	    $cids{$a2} = $id2;
	}
    }
}

foreach my $aid (keys %cids){
    print $aid." ".$cids{$aid}."\n";
}

sub load_stop_words {
    my $stop_words = {};
    my $stop_words_file = "./stop_words.txt";
    open SW, $stop_words_file or die $!;
    while(<SW>) {
	chomp($_);
	$stop_words->{$_} = 1;
    }
    return $stop_words;
}

sub remove_stop_words {
    my $str = shift;
    foreach my $sw (keys %{$stop_words}) {
	$str =~ s/(\b)$sw\b//g;
    }
    $str =~ s/\s+/ /g;
    return $str;
}

sub get_shingles {
    my $str = shift;
    my $n = shift;

    my $shingle_store = {};

    my @words = split(/\s+/, $str);
    
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
