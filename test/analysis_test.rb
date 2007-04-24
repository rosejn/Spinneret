$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'
require 'spinneret'

require 'rubygems'
require 'gosim'

class TestAnalysis < Test::Unit::TestCase
  
  include Spinneret

  def setup
    @sim = GoSim::Simulation::instance
    @sim.quiet

    @config = Configuration::instance
    @config.maintenance_algorithm = Maintenance::Pull

    @pad = Scratchpad::instance
  end

  def teardown
    @sim.reset
  end

  def test_connected
    @pad.nodes = []
    @pad.nodes[0] = Spinneret::Node.new(0) 
    4.times do |i| 
      @pad.nodes << Spinneret::Node.new(i+1, @pad.nodes[i].addr)
    end

    @sim.run(5000)

    analyzer = Spinneret::Analyzer::instance.enable

    return if analyzer.graph.nil?

    assert_equal(true, analyzer.is_connected?)
    assert_equal(1, analyzer.connected_components)

    @pad.nodes << Spinneret::Node.new(100) 
    assert_equal(false, analyzer.is_connected?)
    assert_equal(2, analyzer.connected_components)

    @pad.nodes << Spinneret::Node.new(101) 
    assert_equal(false, analyzer.is_connected?)
    assert_equal(3, analyzer.connected_components)
  end
end

