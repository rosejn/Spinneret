$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'
require 'spinneret'

require 'rubygems'
require 'gosim'

class KWalkerNode < Spinneret::Node
  attr_reader :got_response, :packet_counter

  # TODO: What do we want to do with search responses?
  def handle_kwalker_response(pkt)
    log "node: #{@nid} got response from #{pkt.src_id}"
    @got_response ||= []
    @got_response << pkt.src_id
  end

  def schedule_search(src_id, query_id, time)
    set_timeout(time) { handle_search_kwalk(query_id, src_id, 1, 10) }
  end

  def send_packet(*args)
    @packet_counter ||= 0
    @packet_counter += 1
    super(*args)
  end
end

class TestKWalker < Test::Unit::TestCase
  
  include Spinneret

  def setup
    @sim = GoSim::Simulation.instance
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
    node_a = KWalkerNode.new(0)
    node_b = KWalkerNode.new(1, Peer.new(node_a.addr, node_a.nid))
    node_c = KWalkerNode.new(2, Peer.new(node_b.addr, node_b.nid))
    node_d = KWalkerNode.new(3, Peer.new(node_c.addr, node_c.nid))

    @pad.nodes << node_a << node_b << node_c << node_d

    # Verify that responses come back correctly
    node_b.schedule_search(node_a.addr, node_b.nid, 1)

    # Verify the direct neighbor lookup
    node_c.schedule_search(node_a.addr, node_b.nid, 1)

    # Verify the non-neighbor "random" case
    node_d.schedule_search(node_a.addr, node_b.nid, 1)
    @sim.run(20000)

    assert_equal(1, node_a.got_response.uniq[0])
#    3.times { assert_equal(1, node_a.got_response.shift) }

    # Test that the ttl expiration works (don't send more packets)
    count = node_a.packet_counter
    node_a.kwalker_query(123, 123, 123, 123, 0)
    assert_equal(count, node_a.packet_counter)
  end
end
