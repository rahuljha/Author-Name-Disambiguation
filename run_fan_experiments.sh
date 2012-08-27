echo "For $1"
./create_dblp_fan_graph.pl $1 > /dev/null
./get_fan_valid_paths.pl $1 > /dev/null
./compute_fan_similarity.pl $1
./apcluster files/$1.sims median test > /dev/null
./fan_evaluate.pl files/$1.gold test/idx.txt files/$1.idmap 
