#! /bin/sh

term='postscript eps color "Times-Roman" 15'
size="0.6,0.6"
graph_data="graph_data"
output_dir="plots"

gnuplot <<EOF
set term $term
set size $size
set output "$output_dir/hops_by_tbl_size.eps"
set xlabel "Table Size"
set ylabel "Hops to find key" 1
set logscale x
set yrange [2:20]
set xrange [7:260]
set style line 1 lw 4
set style line 2 lw 4 
plot "hops_by_tbl_size.data" using 1:2 title "Greedy" with lines lw 4, \
		 "kwalk_hops_by_tbl_size.data" using 1:2 title "K-walkers" with lines lw 4
EOF

input_dir="maintenance_overhead_churn_rates/workload-workloads/1000_mxt"
input_dir_end="_s-all-20000.wl.gz__sim_length-4140000__link_table.max_peers-64/packet_neighbor_request"

gnuplot <<EOF
set term $term
set size $size
set output "$output_dir/mesg_by_churn.eps"
set ylabel "Maintenance messages (per node)"
set xlabel "Simulation Time (mins)" 1
#set logscale x
#set yrange [2:20]
set xrange [0:40]
set style line 1 lw 4
set style line 2 lw 4 
plot "${input_dir}60000${input_dir_end}" using (\$1/60000):(\$2/1000) title "1 min. mean failure" with lines lw 4, \
     "${input_dir}120000${input_dir_end}" using (\$1/60000):(\$2/1000) title "2 min. mean failure" with lines lw 4, \
		 "${input_dir}240000${input_dir_end}" using (\$1/60000):(\$2/1000) title "4 min. mean failure" with lines lw 4, \
		 "${input_dir}480000${input_dir_end}" using (\$1/60000):(\$2/1000) title "8 min. mean failure" with lines lw 4, \
		 "${input_dir}960000${input_dir_end}" using (\$1/60000):(\$2/1000) title "16 min. mean failure" with lines lw 4, \
		 "${input_dir}3840000${input_dir_end}" using (\$1/60000):(\$2/1000) title "64 min. mean failure" with lines lw 4
EOF

input_dir_end="_s-all-20000.wl.gz__sim_length-4140000__link_table.max_peers-64/search_success_pct_dht"

gnuplot <<EOF
set term $term
set size $size
set output "$output_dir/delivery_by_churn.eps"
set ylabel "Greedy Pct. Search Success Rate"
set xlabel "Simulation Time (mins)" 1
#set logscale x
#set yrange [2:20]
set xrange [0:40]
set style line 1 lw 4
set style line 2 lw 4 
plot "${input_dir}60000${input_dir_end}" using (\$1/60000):2 title "1 min. mean failure" with lines lw 4, \
     "${input_dir}120000${input_dir_end}" using (\$1/60000):2 title "2 min. mean failure" with lines lw 4, \
     "${input_dir}240000${input_dir_end}" using (\$1/60000):2 title "4 min. mean failure" with lines lw 4, \
		 "${input_dir}480000${input_dir_end}" using (\$1/60000):2 title "8 min. mean failure" with lines lw 4, \
		 "${input_dir}960000${input_dir_end}" using (\$1/60000):2 title "16 min. mean failure" with lines lw 4, \
		 "${input_dir}3840000${input_dir_end}" using (\$1/60000):2 title "64 min. mean failure" with lines lw 4
EOF

input_dir="maintenance_overhead_search_rates/workload-workloads/1000_mxt480000_s-all-"
input_dir_end=".wl.gz__sim_length-780000__link_table.max_peers-32/packet_neighbor_request"

gnuplot <<EOF
set term $term
set size $size
set output "$output_dir/mesg_by_search.eps"
set ylabel "Maintenance messages (per node)"
set xlabel "Simulation Time (mins)" 1
#set logscale x
#set yrange [2:20]
set xrange [0:20]
set style line 1 lw 4
set style line 2 lw 4 
plot "${input_dir}2000${input_dir_end}" using (\$1/60000):(\$2/1000) title "2 sec." with lines lw 4, \
     "${input_dir}20000${input_dir_end}" using (\$1/60000):(\$2/1000) title "20 sec." with lines lw 4, \
		 "${input_dir}40000${input_dir_end}" using (\$1/60000):(\$2/1000) title "40 sec." with lines lw 4, \
		 "${input_dir}120000${input_dir_end}" using (\$1/60000):(\$2/1000) title "2 min." with lines lw 4
EOF

#
#plot './n1000-pause60000-search.wl.gz__node.maintenance_opportunistic_alwayson-false__link_table.address_space_divider-2__link_table.max_peers-32/in-avgs' using 1:3 with lines title '2', './n1000-pause60000-search.wl.gz__node.maintenance_opportunistic_alwayson-false__link_table.address_space_divider-4__link_table.max_peers-32/in-avgs' using 1:3 with lines title '4', './n1000-pause60000-search.wl.gz__node.maintenance_opportunistic_alwayson-false__link_table.address_space_divider-8__link_table.max_peers-32/in-avgs' using 1:3 with lines title '8', './n1000-pause60000-search.wl.gz__node.maintenance_opportunistic_alwayson-false__link_table.address_space_divider-16__link_table.max_peers-32/in-avgs' using 1:3 with lines title '16', './n1000-pause60000-search.wl.gz__node.maintenance_opportunistic_alwayson-false__link_table.address_space_divider-32__link_table.max_peers-32/in-avgs' using 1:3 with lines title '32'

# plot 'n1000-pause60000-search.wl.gz__node.maintenance_opportunistic_alwayson-false__link_table.address_space_divider-2__link_table.max_peers-16/search_success_pct_kwalker' with lines title '2', 'n1000-pause60000-search.wl.gz__node.maintenance_opportunistic_alwayson-false__link_table.address_space_divider-4__link_table.max_peers-16//search_success_pct_kwalker' with lines title '4', 'n1000-pause60000-search.wl.gz__node.maintenance_opportunistic_alwayson-false__link_table.address_space_divider-8__link_table.max_peers-16/search_success_pct_kwalker' with lines title '8', 'n1000-pause60000-search.wl.gz__node.maintenance_opportunistic_alwayson-false__link_table.address_space_divider-16__link_table.max_peers-16/search_success_pct_kwalker' with lines title '16', 'n1000-pause60000-search.wl.gz__node.maintenance_opportunistic_alwayson-false__link_table.address_space_divider-32__link_table.max_peers-16/search_success_pct_kwalker' with lines title '32'
