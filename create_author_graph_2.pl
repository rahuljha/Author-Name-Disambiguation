#!/usr/bin/perl

# Read evaluation file for a single cluster and create author collaboration graph
# Print out in edge-edge format

my $BASE_DIR = "./files";

my $all_authors = "/home/rahuljha/author_name_normalization/OA_authors.txt";
my $eval_dir = "/home/rahuljha/author_name_normalization/evaluation_data";
my %id_hash = ();

#$ARGV[0] =~ m/.*\/(.*)\.txt$/;
my $key = shift;

open GOLD, ">$BASE_DIR/$key.gold" or die $!;
open GRAPH, ">$BASE_DIR/$key.graph" or die $!;
open DATA, ">$BASE_DIR/$key.data" or die $!;

open READ_FILE, "$eval_dir/$key.txt" or die $!;

my $cnt = 1;
while(<READ_FILE>) {
    my $curauth_id = $cnt;
    $cnt++;

    print DATA "$curauth_id ::: $_";
    chomp($_);
    my ($cid, $curauth, $pid, $t2, $t3, $email, $aff) = split(/ ::: /, $_);
    print GOLD "$curauth_id $cid\n";
    my $co_author_str = `cat $all_authors | grep ^$pid`;
    @co_authors = split(/\n/, $co_author_str);
    foreach my $co_author (@co_authors) {
	$norm_coauth = normalize_coauthor($co_author);
	my $norm_coauth_orig = normalize_author($co_author);
	next if $norm_coauth_orig eq $curauth;
	my $coauth_id = null;
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

sub normalize_author {
    my $author_str = shift;
    chomp($author_str);
    next if $author_str eq "";
    my @arr = split(/ ::: /, $author_str);
    my $lname = $arr[1];
    my $fname = $arr[2];
    $fname =~ s/-/ /g;
    my @fname_arr = split(/\s+/, $fname);

    my $out = $lname;

    foreach my $p (@fname_arr) {
	$out = substr($p, 0, 1).$out;
    }
    return lc($out);
}

sub normalize_coauthor {
    my $author_str = shift;
    chomp($author_str);
    next if $author_str eq "";
    my @arr = split(/ ::: /, $author_str);
    my $lname = $arr[1];
    my $fname = $arr[2];
    $fname =~ s/-/ /g;
    my @fname_arr = split(/\s+/, $fname);

    my $out = $lname;

    $out = $fname_arr[0].$out;
    return lc($out);
}
