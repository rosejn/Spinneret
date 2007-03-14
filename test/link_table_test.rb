$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'
require 'spinneret'

class FakeNode
  attr_reader :addr, :nid

  def initialize(addr, nid)
    @addr = addr
    @nid = nid
  end
end

class TestLinkTable < Test::Unit::TestCase

  include Spinneret

  TEST_ADDR = 0
  TEST_NID  = 0
  TEST_SLOTS = 2
  TEST_ADDRESS_SPACE = 1000
  
  def setup
    @node = FakeNode.new(TEST_ADDR, TEST_NID)
    @table = LinkTable.new(@node)

    @config = Configuration.instance.link_table
    @config.address_space = TEST_ADDRESS_SPACE
  end

  def test_basic
    root = Node.new(0)
    @table = LinkTable.new(root)
    num_nodes = 10

    nodes = []
    num_nodes.times do |i| 
      nodes << Node.new(2**i)
      @table.store_peer(nodes.last.addr) 
    end

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
