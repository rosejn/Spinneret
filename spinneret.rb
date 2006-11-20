#!/usr/bin/env ruby

require 'rubygems'
require 'gosim'

#require 'faster_csv'  # For loading topologies

#require 'breakpoint'  # Fixin' up
require 'benchmark'    # Checkin out
#require 'profile'     # Speedin' up

require 'node'

module Spinneret
  NUM_NODES = 10

  # Create the simulation
  sim = GoSim::Simulation.instance

  # Create a little network
  nodes = []
  NUM_NODES.times do |i| 
    peer = nodes[rand(nodes.size)]
    if peer
      nodes << Node.new(i, peer.addr)
    else
      nodes << Node.new(i)
    end
  end

  sim.verbose

  puts "Beginning simulation...\n"
  puts "Simulation Runtime Statistics: \n\n"
  Benchmark.bm do |stat|
    stat.report { sim.run(100) }
  end

  nodes.each {|n| puts n.link_table.inspect }
end
