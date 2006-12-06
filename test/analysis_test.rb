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

  def test_connected
    nodes = []

    nodes[0] = Spinneret::Node.new(0) 
    4.times do |i| 
      nodes << Spinneret::Node.new(i+1, {
        :start_peer => Peer.new(nodes[i].addr, nodes[i].nid),
        :maintenance => Maintenance::Pull }) 
    end

    @sim.run(500)

    analyzer = Analyzer.new(nodes, Spinneret::Node::DEFAULT_ADDRESS_SPACE)
    assert_equal(true, analyzer.is_connected?)
    assert_equal(1, analyzer.connected_components)

    nodes << Spinneret::Node.new(100) 
    assert_equal(false, analyzer.is_connected?)
    assert_equal(2, analyzer.connected_components)

    nodes << Spinneret::Node.new(101) 
    assert_equal(false, analyzer.is_connected?)
    assert_equal(3, analyzer.connected_components)
  end
end

