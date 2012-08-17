#!/bin/bash

base="./files";
# generate data
#./create_author_graph.pl $1
# do afflitiation hash matching
#./aff_hash_matching.pl $base/$1.data > $base/$1.affres
#echo "Affilitation hash matching:"
#./evaluate.pl $base/$1.gold $base/$1.affres

# do afflitiation shingling matching
#./aff_jaccard_email_matching.pl $base/$1.data > $base/$1.jcres
#echo "Affilitation jaccard matching:"
#./evaluate.pl $base/$1.gold $base/$1.jcres

# do author hit time based matching

#./find_commute_time.pl $base/$1.graph $base/$1.data > $base/$1.hits
./cluster_ht_based.pl $base/$1.hits $2 > $base/$1.hitclusts

echo "Author Hitting time based matching:"
./evaluate.pl $base/$1.gold $base/$1.hitclusts 

# full graph hit time based matching
# ./create_full_graph.pl $1
#./find_hitting_time_fg.pl $base/$1.fullgraph $base/$1.fulldata > $base/$1.fullhits
#./cluster_ht_based.pl $base/$1.fullhits $2 > $base/$1.fullhitclusts

#echo "Full graph Hitting time based matching:"
#./evaluate.pl $base/$1.fullgold $base/$1.fullhitclusts 