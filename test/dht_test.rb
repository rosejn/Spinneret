$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'
require 'spinneret'

require 'rubygems'
require 'gosim'

class DHTNode < Spinneret::Node
  attr_reader :responses, :packet_counter

  # TODO: What do we want to do with search responses?
  def dht_response(uid, peer_nid)
    log {"node: #{@nid} got response from #{peer_nid}"}
    @responses ||= []
    @responses << peer_nid
  end

  def schedule_search(query_id, time)
    log {"node: #{nid} querying for #{query_id}"}
    set_timeout(time) { search_dht(query_id) }
  end
end


class TestDHT < Test::Unit::TestCase
  
  include Spinneret

  def setup
    @sim = GoSim::Simulation.instance
    @sim.quiet

    @config = Configuration.instance

    @pad = Scratchpad::instance

    Spinneret::Analyzer::instance.disable
    srand(0)
  end

  def teardown
    @sim.reset
  end

  def test_dht_query
    @sim.verbose

    nodes = []

    # Create a 100 node network and let it stabilize, then run test queries.
    nodes << DHTNode.new(0)
    100.times do |i| 
      nodes << DHTNode.new(i+1, nodes.last.addr)
    end

    @sim.run(65000)

    # Verify that responses come back correctly
    queries = [1, 17, 23, 33, 46, 57, 60, 78, 80, 92]
    queries.each {|q| nodes[0].schedule_search(q, 1) }

    nodes.each {|n| n.stop_maintenance }
    @sim.run(120000)

    assert_not_nil(nodes[0].responses) 
    assert_equal(queries.sort, nodes[0].responses.uniq.sort) 
    
    # Test that the ttl expiration works (don't send more packets)
    # NOTE: This needs to be redone for RPC stuff...
#    count = nodes[92].packet_counter
#    nodes[92].dht_query(nil, 123, 123, 0)
#    assert_equal(count, nodes[92].packet_counter)
  end
end
