$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'
require 'spinneret'

require 'rubygems'
require 'gosim'

class TestNode < Test::Unit::TestCase
  def setup
    @sim = GoSim::Simulation.instance
    @sim.quiet
  end

  def test_simple_bootstrap
    @sim.verbose

    nodes = []
    Spinneret::Node.new(0) 
    4.times {|i| Spinneret::Node.new(i+1, i) }
    @sim.run
  end
end
