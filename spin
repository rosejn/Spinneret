#!/usr/bin/env ruby
 
# == Synopsis
#
# spin: Run a spinneret simulation
#
# == Usage
#
# spin [-w workload] [-t topology] [-a addr_space]
#
# -h, --help:
#    Show this help
#
# -w filename, --workload filename
#    Set the input workload.  Workloads are generated with 
#    script/gen_workload.
#
# -t filename, --topology filename
#    Set the input topology.  Only required if the workload does not have node
#    joins.  Useful for non-bootstrap testing.
#
# -x num, --max-length num
#    The maximum amount of time to allow the simulation to run
#
# -a num, --address-space num
#    Temporary argument until the framework reads the number out of the
#    workload file.  Must be the same as the workload, or your distance
#    function may break.
#
# -m type, --maintenance type
#    Selects a maintenance type.  Current options are:
#       #{maintenance_types}
#       pull
#       push
#       opportunistic
#    Defaults to pull.

require 'rdoc/usage'

require 'lib/spinneret'
require 'util/workload_parser'
require 'util/graph-rep'

def maintenance_types


end

opts = GetoptLong.new(
        ['--help',               '-h', GetoptLong::NO_ARGUMENT],
        ['--workload',           '-w', GetoptLong::REQUIRED_ARGUMENT],
        ['--topology',           '-t', GetoptLong::REQUIRED_ARGUMENT],
        ['--max-length',         '-x', GetoptLong::REQUIRED_ARGUMENT],
        ['--address-space',      '-a', GetoptLong::REQUIRED_ARGUMENT],
        ['--maintenance',        '-m', GetoptLong::REQUIRED_ARGUMENT] )

addr_space = length = 0
workload = topology = nil
maintenance = "pull"

opts.each do | opt, arg |
  case opt
  when '--help'
    RDoc::usage
  when '--workload'
    workload = arg
  when '--topology'
    topology = arg
  when '--max-length'
    length = arg.to_i
  when '--address-space'
    addr_space = arg.to_i
  when '--maintenance'
    maintenance = arg
  end
end

if((workload.nil? && topology.nil?) || (workload.nil? && addr_space == 0))
  puts "Not enough arguments:"
  puts "\tPlease specify either --workload and/or --topology"
  puts "\tNote that --topology must be accompanied by --address-space\n\n"
  RDoc::usage

  exit(0)
end

node_id_map = {}
nodes = []

# make sure the maintenance type is valid
if !Spineret::Maintenance.const_defined? maintenance.capitalize.to_sym
  puts "Invalid maintenance type #{maintenance}.\n"
  exit(1)
end


if topology
  dist_func = DistanceFuncs::sym_circular(addr_space)
  rt_tbls = LogRandRouteTableParser.new(File.new(topology, "r"), nil, 
                                        dist_func)
  nodes = rt_tbls.get_nodes()
  nodes.each do | n | 
    peer = node_id_map[nodes[rand(nodes.length)]]
    if(!peer.nil?)
      n = Spinneret::Node.new(n, peer, dist_func, addr_space)
    else
      n = Spinneret::Node.new(n, nil, dist_func, addr_space)
    end
    node_id_map[n] = n.sid
    nodes << n
  end
end

if workload
  generators = {}
  wl_settings = nil
  dist_func = nil
  generators[:init] = Proc.new do | opts | 
    nid = opts.to_i
    rand_node = nodes[rand(nodes.length)]
    peer = nil
    if !rand_node.nil?
      peer = Spinneret::Peer.new(rand_node.addr, rand_node.nid) 
    end
    n = Spinneret::Node.new(nid, {:start_peer => peer,
                                  :distance_func => dist_func,
                                  :address_space => wl_settings.addr_space.to_i})
    nodes << n
    n
  end
  wl_settings = WorkloadParser.new(workload, generators, node_id_map)
  addr_space = wl_settings.addr_space.to_i
  dist_func = DistanceFuncs::sym_circular(addr_space)
end

# Add the Analysis generation
Spinneret::Analyzer.new(nodes, :address_space => addr_space)

puts "Beginning simulation...\n"
if length != 0
  GoSim::Simulation.run(length) 
else
  GoSim::Simulation.run() 
end

# puts "Simulation Runtime Statistics: \n\n"
#  Benchmark.bm do |stat|
#    stat.report { sim.run(100) }
#  end

#  nodes.each {|n| puts n.link_table.inspect }
