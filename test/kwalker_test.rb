$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'
require 'spinneret'

require 'rubygems'
require 'gosim'

class KWalkerNode < Spinneret::Node
  attr_reader :got_response, :packet_counter

  def initialize(id, bootstrap_node = nil)
    super(id, bootstrap_node)
    @got_response = []
    @packet_counter = 0
  end

  # TODO: What do we want to do with search responses?
  def kwalker_response(uid, peer_addr, ttl, found)
    @got_response << peer_addr  if found
  end

  def schedule_search(query_id, time)
    set_timeout(time) { search_kwalk(query_id, @addr, 1, 10) }
  end

  def send_packet(*args)
    @packet_counter += 1
    super(*args)
  end
end

class TestKWalker < Test::Unit::TestCase
  
  include Spinneret

  def setup
    @sim = GoSim::Simulation::instance
    @sim.quiet

    @config = Configuration::instance

    @pad = Scratchpad::instance
    @pad.nodes = []

    Spinneret::Analyzer::instance.enable
  end

  def teardown
    @sim.reset
  end

  def test_kwalker
    #@sim.verbose

    node_a = KWalkerNode.new(0)
    node_b = KWalkerNode.new(1, node_a.addr)
    node_c = KWalkerNode.new(2, node_b.addr)
    node_d = KWalkerNode.new(3, node_c.addr)

    @pad.nodes << node_a << node_b << node_c << node_d

    # Verify that responses come back correctly
    node_b.schedule_search(node_a.nid, 1000)

    # Verify the direct neighbor lookup
    node_c.schedule_search(node_a.nid, 2000)

    # Verify the non-neighbor "random" case
    node_d.schedule_search(node_a.nid, 3000)

    @sim.run(5000)

    assert_equal(1, node_b.got_response.size)
    assert_equal(1, node_c.got_response.size)
    assert_equal(1, node_d.got_response.size)

    # Test that the ttl expiration works (don't send more packets)
    count = node_a.packet_counter
    node_a.kwalker_query(123, 123, 123, 123, 0)
    assert_equal(count, node_a.packet_counter)
  end
end
