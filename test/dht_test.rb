$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'
require 'spinneret'

require 'rubygems'
require 'gosim'

class DHTNode < Spinneret::Node
  attr_reader :responses, :packet_counter

  # TODO: What do we want to do with search responses?
  def handle_dht_response(pkt)
    log "node: #{@nid} got response from #{pkt.src_id}"
    @responses ||= []
    @responses << pkt.src_id
  end

  def schedule_search(query_id, time)
    log "node: #{nid} querying for #{query_id}"
    set_timeout(time) { handle_search_dht(query_id) }
  end

  def send_packet(*args)
    @packet_counter ||= 0
    @packet_counter += 1
    super(*args)
  end
end


class TestDHT < Test::Unit::TestCase
  
  include Spinneret

  def setup
    @sim = GoSim::Simulation.instance
    @sim.quiet

    @config = Configuration.instance

    @pad = Scratchpad::instance
    @pad.nodes = []

    Spinneret::Analyzer::instance.disable
    srand(0)
  end

  def teardown
    @sim.reset
  end

  def test_dht_query
    # Create a 100 node network and let it stabilize, then run test queries.
    @pad.nodes << DHTNode.new(0)
    100.times do |i| 
      peer = Peer.new(@pad.nodes[i].addr, @pad.nodes[i].nid)
      @pad.nodes << DHTNode.new(i+1, peer)
    end

    @sim.run(60000)

    # Verify that responses come back correctly
    queries = [1, 17, 23, 33, 46, 57, 60, 78, 80, 92]
    queries.each {|q| @pad.nodes[0].schedule_search(q, 1) }

    @pad.nodes.each {|n| n.stop_maintenance }
    @sim.run(120000)

    assert_not_nil(@pad.nodes[0].responses) 
    assert_equal(queries.sort, @pad.nodes[0].responses.uniq.sort) 
    
    # Test that the ttl expiration works (don't send more packets)
    count = @pad.nodes[92].packet_counter
    @pad.nodes[92].dht_query(nil, 123, 123, 0)
    assert_equal(count, @pad.nodes[92].packet_counter)
  end
end
