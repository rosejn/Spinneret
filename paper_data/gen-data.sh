#! /bin/sh

./create-avgs.rb table_size_and_distribution/converge_quit-60000__workload-workloads/1000_j10_s-all-20000_c-off.wl.gz__link_table.size_function-homogeneous__link_table.max_peers-\* dht_hop_average 10 1 > hops_by_tbl_size.data

./create-avgs.rb table_size_and_distribution/converge_quit-60000__workload-workloads/1000_j10_s-all-20000_c-off.wl.gz__link_table.size_function-homogeneous__link_table.max_peers-\* kwalker_hop_average 10 1 > kwalk_hops_by_tbl_size.data
