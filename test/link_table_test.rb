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

  # Do a more targetted test to verify the trimming strategy.
  def test_trim
    nids = [2, 5, 20, 30, 31, 38, 44, 75, 76, 90]
    @table.max_peers = nids.size

    nids.each {|nid| @table.store_peer(Peer.new(0, nid)) }
    assert_equal(nids.size, @table.size)

    # Test boundaries and middle
    insertions = [1, 25, 91]
    removals = [76, 31, 90]
    insertions.each_with_index do |nid, i| 
      @table.store_peer(Peer.new(0, nid)) 
      puts @table.peers.map {|p| p.nid}.sort.join(', ')
      assert_equal(false, @table.has_nid?(removals[i]))
    end
  end
  
=begin
  # Do a more targetted test to verify the trimming strategy.
  def test_distribution
    @table = LinkTable.new(0, {
      :num_slots => TEST_SLOTS, 
      :address_space => TEST_ADDRESS_SPACE,
      :distance_func =>  DistanceFuncs.sym_circular(1024) })
    nids = (1..1023).to_a
    @table.max_peers = 25

    fill_table nids
  end

  def fill_table(nids)
    nids = nids.randomize
    nids.each {|nid| @table.store_peer(Peer.new(0, nid)) }
    @table.peers.map {|p| p.distance}.sort.each {|d| printf "%.2f ", d}
    puts @table.peers.sort {|a, b| a.distance <=> b.distance }.map {|p| p.nid}.join(', ') 
  end
=end
end
