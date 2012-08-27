#!/usr/bin/perl

use Clair::Utils::SimRoutines;
use Clair::Network::CFNetwork;

my $key = shift;

my @stop_words = ();
open STOP, "./stop_words.txt" or die $!;
chomp(@stop_words = <STOP>);

open DATA, "../evaluation_data/Giles_DBLP/$key.txt" or die $!;

my $cnt = 1;
my $titles = {};
my @aids = ();
while(<DATA>) {
    chomp($_);
    my ($auths, $title, $venue) = split(/<>/, $_);

    $auths =~ m/(\d+)_(\d+)\s*(.*)$/;
    my $aid = "$1_$2";

    my $norm_title = norm_text($title);
    $titles->{$aid} = $norm_title;
    push(@aids, $aid);
}

close DATA;

for(my $i = 0; $i <= $#aids; $i++) {
    for(my $j = $i+1; $j <= $#aids; $j++) {
	my $a1 = $aids[$i];
	my $a2 = $aids[$j];
	my $sim = GetLexSim($titles->{$a1}, $titles->{$a2});
	print "$a1 $a2 $sim\n";
    }
}

print "done";


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
	$sent =~ s/\b$sw\b//;
    }
    $sent =~ s/\s+/ /g;
    return $sent;
}
