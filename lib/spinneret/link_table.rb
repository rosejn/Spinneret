module Spinneret   
  # A management class sitting on top of the link table.
  class LinkTable
    include Base
    include KeywordProcessor

    def initialize(nid, args = {})
      @nid = nid
      @sim = GoSim::Simulation.instance
      @last_modified = 0

      params_to_ivars(args, {})

      @table = Array.new(Math::log2(@address_space).ceil) { [] }

      @nid_cache = {}
    end

    def peers
      @table.flatten
    end
    
    # Get the node in the table which is closest to <dest_addr>.
    def closest_peer(dest_nid)
      @table.flatten.min do | a, b |
        distance(dest_nid, a.nid) <=> distance(dest_nid, b.nid)     
      end
    end

    # Get a random node from the table.
    def random_peer
      @table.flatten[rand(size)]
    end

    # Choose <num> random nodes from the table.  If there are not as many nodes
    # as were requested and duplicates are not allowed the response will all
    # nodes. If <allow_duplicates> is set to false then the result will not
    # contain the same node twice.
    def random_peers(num_peers, allow_duplicates = true)
      return @table.flatten  if num_peers >= size

      peers = []
      num_peers.times do
        if allow_duplicates
          peers << random_peer
        else
          while(peers.include?(peer = random_peer)); end
          peers << peer
        end
      end

      peers
    end

    # The total number of nodes in the table.
    def size
      @table.flatten.size
    end

    # The distance between two network addresses.
    def distance(x, y)
      @distance_func.call(x, y)
    end
    
    # Whether the table currently contains a specific address.
    def has_nid?(nid)
      @table.flatten.find {|i| i.nid == nid} != nil
    end

    # Store an address in the table if it is new.
    def store_peer(peer)
      return if has_nid?(peer.nid) || peer.nid == @nid

      @nid_cache[peer.nid] = true
      bin = Math::log2(distance(@nid, peer.nid)).floor
      @table[bin] << peer
      @table[bin].shift if @table[bin].size > @num_slots
    end
    alias :<< :store_peer

    def bin_sizes
      @table.map {|i| i.size}
    end

    def each
      @table.flatten.each { | x | yield x }
    end

    def each_bin
      @table.each { | x | yield x }
    end

    def to_s
      peers.map {|i| i.nid }.join(', ')
    end

    def inspect
      "#<Spinneret::LinkTable nid=#{@nid} peers: #{to_s}"
    end

  end

  # Just a container for keeping things like status information about a
  # specific peer in the link table.
  class Peer
    include Base

    attr_reader :addr, :nid, :last_seen
    # We may also have algorithms that use things like rtt to make decisions.
    # What about a generic field that holds algorithm specific data?

    def initialize(addr, nid)
      @addr, @nid = addr, nid
      seen()
    end

    def seen
      @last_seen = GoSim::Simulation::instance.time
    end

  end
end
