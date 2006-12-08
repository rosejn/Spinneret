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
    set_timeout(time) { dht_query(query_id) }
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
#    @sim.verbose
    @nodes = []
    Spinneret::Analyzer::instance.setup(@nodes)
    srand(0)
  end

  def teardown
    @sim.reset
  end

  def test_dht_query
    # Create a 100 node network and let it stabilize, then run test queries.
    @nodes << DHTNode.new(0)
    100.times do |i| 
      peer = Peer.new(@nodes[i].addr, @nodes[i].nid)
      @nodes << DHTNode.new(i+1, {:start_peer => peer })
    end

    @sim.run(80000)

    # Verify that responses come back correctly
    queries = [1, 17, 23, 33, 46, 57, 60, 78, 80, 92]
    queries.each {|q| @nodes[0].schedule_search(q, 1) }

    @nodes.each {|n| n.stop_maintenance }
    @sim.verbose
    @sim.run(120000)

    assert_not_nil(@nodes[0].responses.nil?) 
    assert_equal(queries.sort, @nodes[0].responses.uniq.sort) 
    
    # Test that the ttl expiration works (don't send more packets)
    count = @nodes[92].packet_counter
    @nodes[92].dht_query(123, 123, 0)
    assert_equal(count, @nodes[92].packet_counter)
  end
end
