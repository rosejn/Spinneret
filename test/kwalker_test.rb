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
  end

  def teardown
    @sim.reset
  end

  def test_kwalker
    node_a = KWalkerNode.new(0)
    node_b = KWalkerNode.new(1, :start_peer => node_a)
    node_c = KWalkerNode.new(2, :start_peer => node_b)
    node_d = KWalkerNode.new(3, :start_peer => node_c)

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
    node_a.kwalker_query(nil, 123, 123, 123, 0)
    assert_equal(count, node_a.packet_counter)
  end
end
