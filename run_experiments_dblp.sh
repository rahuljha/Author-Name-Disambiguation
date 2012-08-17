#!/bin/bash

base="./files";
# generate data
./create_dblp_graph.pl $1

# remove earlier cluster files
rm files/$1.clust.*
# create new clusters
echo "Starting with $1 and $2"
./cluster_iteratively.pl $1 $2
echo "Done"
# evaluate
 echo "Iterative matching results for $1:"
 for i in `ls files/$1.clust.*`
 do 
     echo -n $i": ";
     ./evaluate.pl $base/$1.gold $i;
 done
