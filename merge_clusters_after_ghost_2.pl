#!/usr/bin/perl
use Clair::Utils::SimRoutines;
use Clair::Util;

use strict;
use Lingua::Stem;

use Clair::IDF qw($current_dbmname open_nidf get_nidf);

use vars '$current_dbmname';

my $key = shift;


my $gold_file = "./files/$key.gold";
my $ap_file = "./test/idx.txt";
my $id_map_file = "./files/$key.idmap";
my $data_file = "./files/$key.data";

my $data = load_data();

my @stop_words = ();
open STOP, "./stop_words.txt" or die $!;
chomp(@stop_words = <STOP>);

my $pred_labels = create_ap_hash($ap_file, $id_map_file);
my $pred_clusters = {};
while(my ($aid, $cid) = each %$pred_labels) {
    $pred_clusters->{$cid} = [] unless exists $pred_clusters->{$cid};
    push(@{$pred_clusters->{$cid}}, $aid);
}

my $title_map = load_titles($data_file);

#build idf 
my $dbmname = "./idfs/DBLP_$key\_dbm_file";
#my $dbmname = "./idfs/DBLP_dbm_file";
print "Using DBM $dbmname\n";
my $title_string = join("\n", map {norm_text($_)} values %$title_map);

if(! -e $dbmname) {
    Clair::Util::build_idf_by_line($title_string, $dbmname); 
}

open_nidf($dbmname);

my $clust_to_text = {};

foreach my $cid (keys %$pred_clusters) {
    my $papers = $pred_clusters->{$cid};
    my $text = "";
    foreach my $t (@$papers) {
	$text = $text."\n".norm_text($title_map->{$t});
    }
    $text =~ s/^\s+//g;
    $clust_to_text->{$cid} = $text;
}

my $sims = {};
my @cids = sort {$a <=> $b} keys %$clust_to_text;

# print desc_cluster($_) foreach (@cids);
# exit;

my $new_clusts = {};
my $idx = $cids[$#cids]+1;

for(my $i=0; $i<=$#cids; $i++) {
    for(my $j=$i+1; $j<=$#cids; $j++) {
	my $id1 = $cids[$i];
	my $id2 = $cids[$j];
	my $len1 = $#{$pred_clusters->{$id1}}+1;
	my $len2 = $#{$pred_clusters->{$id2}}+1;
	my $sim1 = get_max_similarity($id1, $id2);
	my $sim2 = get_lex_sim($id1, $id2);
	if($sim1 > 0.4 || $sim2 > 0.4) {
	    if(exists $new_clusts->{$id1}) {
		$new_clusts->{$id2} = $new_clusts->{$id1};
	    } elsif(exists $new_clusts->{$id2}) {
		$new_clusts->{$id1} = $new_clusts->{$id2};
	    } else {
		$new_clusts->{$id1} = $idx;
		$new_clusts->{$id2} = $idx;
		$idx++;
	    }
	}
	$sims->{"$id1($len1)\_$id2($len2)"} = $sim1;
    }
}

my @sorted_sims = sort {$sims->{$b} <=> $sims->{$a}} keys %$sims;

foreach my $key (@sorted_sims) {
    print "$key: ".$sims->{$key}."\n";
}

my $new_cluster_file = ">./files/$key.newclusts";
open NEW_CLUSTS, $new_cluster_file or die $!;
foreach my $aid (sort {$a <=> $b} keys %$pred_labels) {
    my $cid = $pred_labels->{$aid};
    if(exists $new_clusts->{$cid}) {
	print NEW_CLUSTS "$aid ".$new_clusts->{$cid}."\n";
    } else {
	print NEW_CLUSTS "$aid $cid\n";
    }
}

print "done";

sub get_lex_sim {
    my $id1 = shift;
    my $id2 = shift;

    my $t1 = $clust_to_text->{$id1};
    my $t2 = $clust_to_text->{$id2};

    $t1 =~ s/\n//;
    $t2 =~ s/\n//;

    return GetLexSim($t1, $t2);
}

sub get_avg_similarity {
    my $id1 = shift;
    my $id2 = shift;

    my $t1 = $clust_to_text->{$id1};
    my $t2 = $clust_to_text->{$id2};

    my @c1 = split(/\n/, $t1);
    my @c2 = split(/\n/, $t2);

    my $total_sim = 0;
    my $cnt = 0;
    foreach my $s1 (@c1) {
	foreach my $s2 (@c2) {
	    my $sim = GetLexSim($s1, $s2);
	    $total_sim += $sim;
	    $cnt++;
	}
    }

    my $avg_sim = ($cnt == 0) ? 0 : $total_sim/$cnt;
    return $avg_sim;
}

sub get_max_similarity {
    my $id1 = shift;
    my $id2 = shift;

    my $t1 = $clust_to_text->{$id1};
    my $t2 = $clust_to_text->{$id2};

    my @c1 = split(/\n/, $t1);
    my @c2 = split(/\n/, $t2);

    my $total_sim = 0;
    my $cnt = 0;
    foreach my $s1 (@c1) {
	my $max_sim = 0;
	foreach my $s2 (@c2) {
	    my $sim = GetLexSim($s1, $s2);
	    $max_sim = $sim if $sim > $max_sim;
	}
	$total_sim += $max_sim;
	$cnt++;
    }

    my $avg_sim = ($cnt == 0) ? 0 : $total_sim/$cnt;
    return $avg_sim;
    
}

sub desc_cluster {
    my $cid = shift;
    my $ids = $pred_clusters->{$cid};
    print "\n--------------\n";
    print "Cluster number: $cid\n";
    print "--------------\n";
    foreach my $id (@$ids) {
	my ($aid, $tmp) = split(/\s+/, $data->{$id});
	print "$aid ";
    }
    print "\n\n".$clust_to_text->{$cid}."\n";
}

sub load_data {
    my $data = {};
    open DATA, $data_file or die $!;
    while(<DATA>) {
	chomp($_);
	my ($id, $line) = split(/ ::: /, $_);
	$data->{$id} = $line;
    }

    return $data;
}

sub load_titles {
    my $data_file = shift;
    my $title_map = {};
    open DATA, $data_file or die $!;
    while(<DATA>) {
	chomp $_;
	$_ =~ m/(\d+)\s+:::\s+[\d\_]+[^<]+<>(.*)<>/;
	my $id = $1;
	my $title = $2;
	$title =~ s/^\s+//;
	$title =~ s/\s+$//;
	$title_map->{$id} = $title;
    }
    return $title_map;
}

sub create_ap_hash {
    my $ap_results = shift;
    my $id_map_file = shift;

    my $hash = {};
    
    open IDMAP, $id_map_file or die $!;
    my %id_map = ();
    while(<IDMAP>) {
	chomp($_);
	my ($dblp_id, $ap_id) = split(/\s+/, $_);
	$id_map{$ap_id} = $dblp_id;
    }

    my $cur_id = 1;
    open AP_RESULT, $ap_results or die $!;
    while(<AP_RESULT>) {
	chomp($_);
	$_ =~ s/^\s+//;
	$_ =~ s/\s+$//;

	my $dblp_id = $id_map{$cur_id};
	
	$hash->{$dblp_id} = $_;
	$cur_id++;
    }

    return $hash;
}

sub in_array {
     my ($arr,$search_for) = @_;
    my %items = map {$_ => 1} @$arr; # create a hash out of the array values
    return (exists($items{$search_for}))?1:0;
}

sub norm_text {
    my $sent = shift;
    $sent =~ s/\d//g;
    $sent =~ s/[;,.]//g;
    $sent =~ s/\(\s*?\)//g;
    $sent =~ s/[^!-~\s]//g;
    $sent =~ s,\c[A-Z],,g;
    $sent =~ s/\W/ /g;
    $sent =~ s/\s+/ /g;
    $sent = lc($sent);
    foreach my $sw (@stop_words) {
	$sent =~ s/\b$sw\b//g;
    }

    $sent = stem($sent);
    return $sent;
}

sub stem {
    my $line = shift;

    my $stemmer = Lingua::Stem->new(-locale => 'EN-US');
    $stemmer->stem_caching({ -level => 2 });
    my @words = split(/\s+/, $line);

    my @stemmed = @{$stemmer->stem(@words)};
    my $stem = join(" ",@stemmed);
    return $stem;
}
