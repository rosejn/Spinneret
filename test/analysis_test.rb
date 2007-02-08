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
    GoSim::Net::Topology::instance.setup(100)
  end

  def teardown
    @sim.reset
  end

  def test_connected
    nodes = []

    nodes[0] = Spinneret::Node.new(0, :maintenance => Maintenance::Pull) 
    4.times do |i| 
      nodes << Spinneret::Node.new(i+1,
        :start_peer => Peer.new(nodes[i].addr, nodes[i].nid),
        :maintenance => Maintenance::Pull) 
    end

    @sim.run(500)

    analyzer = Spinneret::Analyzer::instance.setup(nodes)
    assert_equal(true, analyzer.is_connected?)
    assert_equal(1, analyzer.connected_components)

    nodes << Spinneret::Node.new(100) 
    assert_equal(false, analyzer.is_connected?)
    assert_equal(2, analyzer.connected_components)

    nodes << Spinneret::Node.new(101) 
    assert_equal(false, analyzer.is_connected?)
    assert_equal(3, analyzer.connected_components)
  end

#  def test_fit
#    srand(0)
#    nodes = []
#
#    nodes[0] = Spinneret::Node.new(nil, :address_space => 10000, :max_peers => 10)
#    99.times do |i|
#      start = nodes.rand
#      nodes << Spinneret::Node.new(nil, :start_peer => Peer.new(start.addr, start.nid), :address_space => 10000, :max_peers => 10)
#    end
#
#    printf("nid [25] == %d\n", nodes[25].nid)
#
#    100.times do | i |
#      @sim.run(1000 * i)
#    
#      fit = nodes[25].link_table.fit2
#      printf("N(tbl) = (u = %f, s = %f) [sze = %d]\n", fit[0], fit[1],
#             nodes[25].link_table.size)
##      printf("f(x) = %fx + %f (with rmse %f) [sze = %d]\n", fit[1], fit[0], fit[5],
##             nodes[25].link_table.size)
#    end
#  end
end

