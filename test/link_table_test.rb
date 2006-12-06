$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'
require 'spinneret'


class TestLinkTable < Test::Unit::TestCase

  include Spinneret

  TEST_ADDR = 0
  TEST_SLOTS = 2
  TEST_ADDRESS_SPACE = 1000
  
  def setup
    @table = LinkTable.new(TEST_ADDR, {
      :num_slots => TEST_SLOTS, 
      :address_space => TEST_ADDRESS_SPACE,
      :distance_func =>  DistanceFuncs.sym_circular(TEST_ADDRESS_SPACE) })
  end

  def test_basic
    num_nodes = 10

    # store_addr & size
    num_nodes.times {|i| @table.store_peer(Peer.new(0, 2**i)) }
    assert_equal(num_nodes, @table.size)

    # has_nid?
    assert_equal(true, @table.has_nid?(2**4))

    # closest_peer
    assert_equal(512, @table.closest_peer(480).nid)
    assert_equal(4, @table.closest_peer(5).nid)
    assert_equal(128, @table.closest_peer(136).nid)

    # closest_peers
    assert_equal([8, 16, 32], @table.closest_peers(24, 3).map{|p| p.nid }.sort)

    # random_peer(s)
    assert_equal(Peer, @table.random_peer.class)
    assert_equal(5, @table.random_peers(5).size)
  end
end
