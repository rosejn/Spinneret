$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'
require 'spinneret'

require 'rubygems'
require 'gosim'

class TestAnalysis < Test::Unit::TestCase
  
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
  def test_stability
    nodes = []
    nodes[0] = Spinneret::Node.new(0) 
    
    4.times do |i| 
      nodes << Spinneret::Node.new(i+1, {
        :start_peer => Peer.new(nodes[i].addr, nodes[i].nid),
        :maintenance => Maintenance::Pull }) 
    end

    @sim.run(500)

    nodes.each { | n | assert_equal(4, n.link_table.size) }
  end
end

