$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'
require 'spinneret'

require 'rubygems'
require 'gosim'

class TestNode < Test::Unit::TestCase
  
  include Spinneret

  def setup
    @sim = GoSim::Simulation.instance
    @sim.quiet
  end

  def test_simple_bootstrap
    @sim.verbose

    nodes = []
    nodes[0] = Spinneret::Node.new(0) 
    
    4.times do |i| 
      nodes << Spinneret::Node.new(i+1, {
        :start_peer => Peer.new(nodes[i].nid, nodes[i].addr) }) 
    end

    @sim.run(500)

    nodes.each { | n | assert_equal(4, n.link_table.size) }
  end
end
