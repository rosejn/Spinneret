#!/usr/bin/env ruby
 
# == Synopsis
#
# spinneret: Run a spinneret simulation
#
# == Usage
#
# spinneret.rb [OPTIONS]
#
# -h, --help:
#    Show this help
#
# -w filename, --workload filename
#    Set the input workload.  Workloads are generated with 
#    gen-spinneret-wl.rb.
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

# Builtins
require 'rdoc/usage'

#require 'breakpoint'  # Fixin' up
require 'benchmark'    # Checkin out
#require 'profile'     # Speedin' up

# Externals
require 'rubygems'
require 'zlib'
require 'gosim'

# Internals
require 'node'
require 'graph-rep'
require 'wl-parser'
require 'dist-funcs'

opts = GetoptLong.new(
        ['--help',               '-h', GetoptLong::NO_ARGUMENT],
        ['--workload',           '-w', GetoptLong::REQUIRED_ARGUMENT],
        ['--topology',           '-t', GetoptLong::REQUIRED_ARGUMENT],
        ['--max-length',         '-x', GetoptLong::REQUIRED_ARGUMENT],
        ['--address-space',      '-a', GetoptLong::REQUIRED_ARGUMENT] )

addr_space = length = 0
workload = topology = nil
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
  end
end

if((workload.nil? && topology.nil?) || (workload.nil? && addr_space == 0))
  printf("Need to specify and either --workload and/or --topology, and " +
         "--topology must\nbe accomponied by --address-space.\n")
  exit(0)
end

node_objs = {}
dist_func = DistanceFuncs::sym_circular(addr_space)
if(!topology.nil?)
  rt_tbls = LogRandRouteTableParser.new(Zlib::GzipReader.open(topology),
                                        nil, dist_func)
  nodes = rt_tbls.get_nodes()
  nodes.each do | n | 
    peer = node_objs[nodes[rand(nodes.length)]]
    if(!peer.nil?)
      node_objs[n] = Spinneret::Node.new(n, peer, dist_func, addr_space).sid
    else
      node_objs[n] = Spinneret::Node.new(n, nil, dist_func, addr_space).sid
    end
  end
end

if(!workload.nil?)
  generators = {}
  wl_settings = nil
  generators[:init] = Proc.new do | opts | 
    Spinneret::Node.new(opts.to_i, nil, dist_func, wl_settings.addr_space)
  end
  wl_settings = WorkloadParser.new(workload, generators, node_objs)
end

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
