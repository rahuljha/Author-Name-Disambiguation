#!/usr/bin/perl
#
# script: wordnet_to_network.pl
# functionality: Generates a synonym network from WordNet
#

use strict;
use warnings;

#use WordNet::QueryData;
use Getopt::Long;

sub usage;
sub remove_negations;
sub remove_stop_words;
sub get_hitting_time;
sub sim_random_walk;

my $out_file = "";
my $verbose = 0;
my $word = "";
my $word_file = "";
my $pos_words_file = "";
my $neg_words_file = "";
my $steps;
my $num_samples;
my $rounds;
my $label;
my $method = "";
my $res = GetOptions("out=s" => \$out_file, "samples=s" => \$num_samples, "poswords=s" => \$pos_words_file,"negwords=s" => \$neg_words_file, "steps=i" => \$steps, "word=s" => \$word_file, "label=i" => \$label, "method=s" => \$method);

if (!$res) 
{
  usage();
  exit;
}

my $wn_data_home = "/data0/projects/scil/word_polarity/wordnet_data";

#my $wn = WordNet::QueryData->new;

# Load positive words
my %poswords;
open(F1,$pos_words_file);
while(<F1>)
{
	chomp;
	$_ =~ s/#[a-z]//;
	$poswords{$_} = 1;
}

# Load negative words
my %negwords;
open(F2,$neg_words_file);
while(<F2>)
{
    chomp;
	$_ =~ s/#[a-z]//;
    $negwords{$_} = 1;
}

#my %words2remove;
#open(F3,"words2remove");
#while(<F3>)
#{
#	chomp;
#	$words2remove{$_} = 1;
#}


my %wn_syns;
open(FSYNS,"$wn_data_home/wordnet.syns");
while(<FSYNS>)
{
	chomp;
	my ($w,$syns) = split(/\t/,$_);
	if($syns ne ""){$wn_syns{$w} = $syns;};
}

my %wn_sim;
open(FSIM,"$wn_data_home/wordnet.sim");
while(<FSIM>)
{
    chomp;
    my ($w,$syns) = split(/\t/,$_);
    if($syns ne ""){$wn_sim{$w} = $syns;};
}

my %wn_also;
open(FALSO,"$wn_data_home/wordnet.also");
while(<FALSO>)
{
    chomp;
    my ($w,$syns) = split(/\t/,$_);
    if($syns ne ""){$wn_also{$w} = $syns;};
}


my %wn_hypes;
open(FHYPES,"$wn_data_home/wordnet.hypes");
while(<FHYPES>)
{
    chomp;
	my ($w,$syns) = split(/\t/,$_);
    if($syns ne ""){$wn_hypes{$w} = $syns;};
}



my %wn_hypos;
open(FHYPOS,"$wn_data_home/wordnet.hypos");
while(<FHYPOS>)
{
    chomp;
	my ($w,$syns) = split(/\t/,$_);
    if($syns ne ""){$wn_hypos{$w} = $syns;};
}


my %wn_deri;
open(FDERI,"$wn_data_home/wordnet.deri");
while(<FDERI>)
{
    chomp;
	my ($w,$syns) = split(/\t/,$_);
    if($syns ne ""){$wn_deri{$w} = $syns;};
}

my %wn_occ;
open(FOCC,"$wn_data_home/coocuurance.txt");
while(<FOCC>)
{
    chomp;
    my ($w,$syns) = split(/\t/,$_);
    if($syns ne ""){$wn_occ{$w} = $syns;};
}



my $max_iterations = $steps;

srand;

open(OUT,">$out_file");
select((select(OUT), $|=1)[0]);
open(F4,$word_file);

if($method eq "hitting")
{

while(<F4>)
{
	chomp;
	my $pos_hitting_time = get_sampled_hitting_time($_,1,$num_samples);
	my $neg_hitting_time = get_sampled_hitting_time($_,-1,$num_samples);

	my $pred = 1;
	if($neg_hitting_time < $pos_hitting_time)
	{
		$pred = -1;
	}
	if($out_file eq "")
	{	
		print "$_ $pos_hitting_time $neg_hitting_time $pred $label\n";	
	}
	else
	{
		print OUT "$_ $pos_hitting_time $neg_hitting_time $pred $label\n";
	}
}

}
else
{

while(<F4>)
{
    chomp;
    my ($pos,$neg,$neut) = get_random_walk_pred($_,$num_samples);

    my $pred = 1;
    if($neg > $pos)
    {
        $pred = -1;
    }

	if($out_file eq "")
    {
	    print "$_ $pos $neg $neut $pred $label\n";
	}
	else
	{
		print OUT "$_ $pos $neg $neut $pred $label\n";
	}
}

}

sub get_sampled_hitting_time
{
	my $word = shift;
    my $sign = shift;
	my $num_samples = shift;

	my $sum = 0;
	for(my $i=0; $i<$num_samples; $i++)
	{
		my $h = get_hitting_time($word,$sign,0);
		$sum = $sum + $h;
	}
	return ($sum/$num_samples);
	
}



sub get_hitting_time
{
	my $word = shift;
	my $sign = shift;
	my $iter = shift;


	# stopping condition
	my $x = $word;
    $x =~ s/([a-zA-Z_]*).*/$1/;
	if($sign == 1)
	{
        if(defined $poswords{$x})
        {
			return 0;
        }
	}
	elsif($sign == -1)
	{
		if(defined $negwords{$x})
        {
			return 0;
		}
	}

	if($iter >= $max_iterations)
	{
		return $max_iterations;
	}

	my %syns_hash;
	my $words_str = "";

	if(defined $wn_syns{$word}){ $words_str = $words_str . " " . $wn_syns{$word};  };
	if(defined $wn_sim{$word}){ $words_str = $words_str . " " . $wn_sim{$word};   };
	if(defined $wn_also{$word}){ $words_str = $words_str . " " . $wn_also{$word};  };
	if(defined $wn_deri{$word}){ $words_str = $words_str . " " . $wn_deri{$word};  };
	if(defined $wn_hypes{$word}){ $words_str = $words_str . " " . $wn_hypes{$word}; };

	#if(defined $wn_occ{$word}){ $words_str = $words_str . " " . $wn_occ{$word}; };

#	$words_str =~ s/ $//;
#    $words_str =~ s/^ //;
#	if($words_str eq "")
#	{ 
#	if(defined $wn_hypes{$word}){ $words_str = $words_str . " " . $wn_hypes{$word}; };
#	}
	#$words_str = $words_str . " " . $wn_hypos{$word};

	$words_str =~ s/  */ /g;
	$words_str =~ s/ $//;
	$words_str =~ s/^ //;
	my @tmp = split(/ /,$words_str);
	foreach my $t (@tmp)
	{
		$syns_hash{$t} = 1;
	}

	my @syns = keys %syns_hash;
	if(scalar(@syns) == 0)
	{
		return $max_iterations;
	}
    my $rand = int(rand(scalar(@syns)));
	my $hj = get_hitting_time($syns[$rand],$sign,$iter+1);
	return $hj + 1;

}


sub get_random_walk_pred
{
    my $word = shift;
    my $num_samples = shift;

    my $pos = 0;
	my $neg = 0;
	my $neut = 0;
    for(my $i=0; $i<$num_samples; $i++)
    {
        my $h = sim_random_walk($word,0);
		if($h == 1)
		{
			$pos++;
		}
		elsif($h == -1)
		{
			$neg++;
		}
		elsif($h == 0)
		{
			$neut++;
		}
    }
    return ($pos,$neg,$neut);

}


sub sim_random_walk
{
	my $word = shift;
    my $iter = shift;

    # stopping condition
    my $x = $word;
    $x =~ s/([a-zA-Z_]*).*/$1/;
    if(defined $poswords{$x})
    {
    	return 1;
    }
    elsif(defined $negwords{$x})
    {
            return -1;
    }
    elsif($iter >= $max_iterations)
    {
        return 0;
    }

    my %syns_hash;
    my $words_str = "";

    if(defined $wn_syns{$word}){ $words_str = $words_str . " " . $wn_syns{$word};  };
    if(defined $wn_sim{$word}){ $words_str = $words_str . " " . $wn_sim{$word};   };
    if(defined $wn_also{$word}){ $words_str = $words_str . " " . $wn_also{$word};  };
    if(defined $wn_deri{$word}){ $words_str = $words_str . " " . $wn_deri{$word};  };
    if(defined $wn_hypes{$word}){ $words_str = $words_str . " " . $wn_hypes{$word}; };
    #$words_str = $words_str . " " . $wn_hypos{$word};

    $words_str =~ s/  */ /g;
    $words_str =~ s/ $//;
	$words_str =~ s/^ //;
    my @tmp = split(/ /,$words_str);
	foreach my $t (@tmp)
    {
        $syns_hash{$t} = 1;
    }

    my @syns = keys %syns_hash;
    if(scalar(@syns) == 0)
    {
        return 0;
    }
    my $rand = int(rand(scalar(@syns)));
    my $hj = sim_random_walk($syns[$rand],$iter+1);
    return $hj;
}


sub usage {
  print  "Usage $0 --output output_file [--verbose]\n\n";
  print  "  --output output_file\n";
  print  "       Name of the output graph file\n";
  print  "  --verbose\n";
  print  "       Increase verbosity of debugging output\n";
  print  "\n";
  die;
}

sub remove_negations
{
    $_ = shift;

    s/lacking [a-zA-Z]* or [a-zA-Z]*//g;
    s/lacking [a-zA-Z]* and [a-zA-Z]*//g;
    s/lacking [a-zA-Z]*//g;

    s/lack of [a-zA-Z]* and [a-zA-Z]*//g;
    s/lack of [a-zA-Z]* or [a-zA-Z]*//g;
    s/lack of [a-zA-Z]*//g;

    s/never [a-zA-Z]* and [a-zA-Z]*//g;
    s/never [a-zA-Z]* or [a-zA-Z]*//g;
    s/never [a-zA-Z]*//g;

    s/never making a [a-zA-Z]*//g;
    s/never making an [a-zA-Z]*//g;
    s/never making [a-zA-Z]*//g;

    s/not merely [a-zA-Z]* or [a-zA-Z]*//g;
    s/not merely [a-zA-Z]*//g;

    s/not [a-zA-Z]* or [a-zA-Z]*//g;
    s/not a [a-zA-Z]*//g;
    s/not an [a-zA-Z]*//g;
    s/not of the [a-zA-Z]*//g;
    s/not really [a-zA-Z]*//g;
    s/not fully [a-zA-Z]*//g;
    s/not well [a-zA-Z]*//g;

    s/not [a-zA-Z]* or [a-zA-Z]*//g;
    s/not [a-zA-Z]*//g;

    s/no [a-zA-Z]*//g;

    s/clear of [a-zA-Z]*//g;

    s/free of [a-zA-Z]* and [a-zA-Z]*//g;
    s/free of [a-zA-Z]*//g;
    s/free from [a-zA-Z]*//g;
    s/free from [a-zA-Z]* and [a-zA-Z]*//g;

    s/  */ /g;

    return $_;
}

#sub remove_stop_words
#{
#    my $txt = shift;
#    my @tmp = split(/ /,$txt);
#    my @out = ();
#    foreach my $t(@tmp)
#    {
#       if(not defined $words2remove{$t})
#        {
#            push(@out,$t);
#        }
#    }
#
#    return join(' ',@out);
#}
