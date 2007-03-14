$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'
require 'spinneret'

require 'rubygems'
require 'gosim'

class FailNode < Spinneret::Node
  def initialize(nid, start_peer = nil)
    super
    
    @failed_packets = 0
  end

  def handle_failed_packet(pkt)
    @failed_packets += 1

    log "failed packet: #{pkt.inspect}"
  end
end

class TestNode < Test::Unit::TestCase
  
  include Spinneret

  def setup
    @sim = GoSim::Simulation.instance
    @sim.quiet
  end

  def teardown
    @sim.reset
  end

  # TODO: We might not really need any tests for node as long as it remains a
  # shell for the link table and maintenance algorithms...
  def test_simple_bootstrap
    nodes = []
    nodes[0] = Node.new(0) 
    
    4.times do |i| 
      nodes << Node.new(i+1, nodes[i].addr) 
    end

    @sim.run(50000)

    nodes.each { | n | assert_equal(4, n.link_table.size) }
  end

  def test_failure
    @sim.quiet
    nodes = []
    nodes[0] = Node.new(0) 
    
    4.times do |i| 
      nodes << Node.new(i+1, nodes[i].addr) 
    end

    @sim.schedule_event(:alive, nodes[0].addr, 25000, false)
    @sim.run(50000)

    assert_equal(false, nodes[0].alive?)
  end
end
