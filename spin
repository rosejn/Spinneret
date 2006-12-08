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
# -v, --verbose
#    Be verbose with simulation details.  This is slow, and is off by default.
#
# -w filename, --workload filename
#    Set the input workload.  Workloads are generated with 
#    script/gen_workload.
#
# -t filename, --topology filename
#    Set the input topology.  Only required if the workload does not have node
#    joins.  Useful for non-bootstrap testing.
#
# -l num, --max-length num
#    The maximum amount of time to allow the simulation to run
#
# -a num, --address-space num
#    Temporary argument until the framework reads the number out of the
#    workload file.  Must be the same as the workload, or your distance
#    function may break.
#
# -m type, --maintenance type
#    Selects a maintenance type.  Use '--maintenance help' to get a list of
#    currnetly supported types.  Default is pull.
#
# -s num, --maintenance-size num
#    The number of peers the given maintenance protocol should use during
#    exchange.  This may not map well onto all protocols.  Defaults to 5.

require 'rdoc/usage'

require 'lib/spinneret'
require 'util/workload_parser'
require 'util/graph-rep'

opts = GetoptLong.new(
        ['--help',               '-h', GetoptLong::NO_ARGUMENT],
        ['--verbose',            '-v', GetoptLong::NO_ARGUMENT],
        ['--workload',           '-w', GetoptLong::REQUIRED_ARGUMENT],
        ['--topology',           '-t', GetoptLong::REQUIRED_ARGUMENT],
        ['--max-length',         '-l', GetoptLong::REQUIRED_ARGUMENT],
        ['--address-space',      '-a', GetoptLong::REQUIRED_ARGUMENT],
        ['--maintenance',        '-m', GetoptLong::REQUIRED_ARGUMENT],
        ['--maintenance-size',   '-s', GetoptLong::REQUIRED_ARGUMENT] )

addr_space = length = 0
workload = topology = nil
maintenance = "pull"
maint_size = Spinneret::Node::DEFAULT_MAINTENANCE_SIZE

opts.each do | opt, arg |
  case opt
  when '--help'
    RDoc::usage
  when '--verbose'
    GoSim::Simulation.instance.verbose
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
  when '--maintenance-size'
    maint_size = arg.to_i
  end
end

if((workload.nil? && topology.nil?) || (workload.nil? && addr_space == 0))
  puts "Not enough arguments:"
  puts "\tPlease specify either --workload and/or --topology"
  puts "\tNote that --topology must be accompanied by --address-space\n\n"
  RDoc::usage

  exit(0)
end

if(topology)
  puts "Topologies are not currently supported.\n"
  exit(0)
end

node_id_map = {}
nodes = []

# make sure the maintenance type is valid
maintenance = maintenance.capitalize.to_sym
if !Spinneret::Maintenance.const_defined?(maintenance)
  if maintenance != :Help
    puts "Invalid maintenance type \'#{maintenance.to_s}\'.\n"
  end
  puts "Valid maintenance types are:\n"
  Spinneret::Maintenance.constants.each { |cls| puts "  #{cls.to_s}" }
  exit(1)
else
  maintenance = Spinneret::Maintenance.const_get(maintenance)
end

GoSim::Net::Topology::instance.setup(100)  # Mean latency 

#if topology
#  dist_func = DistanceFuncs::sym_circular(addr_space)
#  rt_tbls = LogRandRouteTableParser.new(File.new(topology, "r"), nil, 
#                                        dist_func)
#  nodes = rt_tbls.get_nodes()
#  nodes.each do | n | 
#    peer = node_id_map[nodes[rand(nodes.length)]]
#    if(!peer.nil?)
#      n = Spinneret::Node.new(n, peer, dist_func, addr_space)
#    else
#      n = Spinneret::Node.new(n, nil, dist_func, addr_space)
#    end
#    node_id_map[n] = n.sid
#    nodes << n
#  end
#end

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
    n = Spinneret::Node.new(nid, {:maintenance => maintenance,
                                  :maintenance_size => maint_size,
                                  :start_peer => peer,
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
Spinneret::Analyzer::instance.setup(nodes, {:address_space => addr_space})

puts "Beginning simulation...\n"
if(length != 0 || wl_settings.sim_length != 0)
  wl_length = wl_settings.sim_length.to_i
  GoSim::Simulation.run((length > wl_length ?  length : wl_length)) 
else
  GoSim::Simulation.run() 
end

# puts "Simulation Runtime Statistics: \n\n"
#  Benchmark.bm do |stat|
#    stat.report { sim.run(100) }
#  end

#  nodes.each {|n| puts n.link_table.inspect }
