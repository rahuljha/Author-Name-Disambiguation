#!/usr/bin/perl

use strict;
use FindBin;


my $datadir = "/storage2/foreseer/users/vahed/topics/data";
my $outdir = "/storage2/foreseer/users/vahed/topics/output";
my $graphf = "$datadir/romney.graph";
my $queryf = "$datadir/romney.query";
my $dataf = "$datadir/romney.data";

my $samplesize = 1000;
my $walklength = 1;

my $resf = "$outdir/HT-$samplesize-$walklength.out";

srand(12345);

my %graph = ();
my %tweets = ();

open IN, $dataf;
while(<IN>)
{
    chomp $_;
    my @ar = split(/\t/, $_);
    my $tid = $ar[2];
    my $txt = $ar[4];
    $tweets{$tid} = $txt;
}
close IN;

open IN, $graphf;
while(<IN>)
{
    chomp $_;
    my @ar = split(/\t/, $_);
    my $id1 = $ar[0];
    my $id2 = $ar[1];
    my $cos = $ar[2];
    if($cos > 0)
    {
	$graph{$id1}{$id2} = $cos;
    }
}
close IN;
print "Reading Graph [Done!]\n";

my %queries = ();
open IN, $queryf;
open OUT, ">$resf";
while(<IN>)
{
    chomp $_;
    my @ar = split(/\t/, $_);
    my $qid = $ar[1];
    print "Searching Query: $qid\n";
    &Search($qid);
}

close OUT;



sub Search
{
    my $qid = shift;

    my %HT = ();
    my %CT = ();
    
    my $c = 0;
    while($c < $samplesize)
    {
	++$c;
	#start a ramdom walk.
	my $curnode = $qid;
	my %cov = ();
	$cov{$curnode} = 1;	
	#print "new walk: ";
	for (my $i = 1; $i<= $walklength; ++$i)
	{
	    #print "$curnode => ";
	    #print "Step = $i\n";
	    my $r = rand();		    
	    my $cursum = 0;
	    for my $nei (keys %{$graph{$curnode}})
	    {
		$cursum += $graph{$curnode}{$nei};
		#print "picking $nei \t $cursum\n";
		if($cursum >= $r)
		{
		    $curnode = $nei;		
		    #print "chose $nei \t $cursum\n";
		    if($cov{$nei} != 1)
		    {
			$cov{$nei} = 1;
			$HT{$nei} = $HT{$nei} + $i;
			$CT{$nei} = $CT{$nei} + 1;
		    }
		    last;
		}
	    }
	}
	#print "\n======================================\n";
	for my $id (keys %tweets)
	{
	    if($cov{$id} != 1)
	    {
		$HT{$id} = $HT{$id} + $walklength + 1;
	    }
	}
    }

    my %scores = ();
    
    for my $id (keys %tweets)
    {
	$scores{$id} = $HT{$id} / $samplesize;		
    }

    my $rank = 0;
    for my $ind (sort {$scores{$a} <=> $scores{$b}} keys %scores)
    {
	++$rank;
	print OUT $qid."\t".$ind."\t".$scores{$ind}."\t".$rank."\n";
    }     
}



