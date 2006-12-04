module Spinneret   
  # A management class sitting on top of the link table.
  class LinkTable
    include Base
    include KeywordProcessor

    attr_reader :last_modified

    def initialize(nid, args = {})
      @nid = nid
      @sim = GoSim::Simulation.instance
      @last_modified = 0

      params_to_ivars(args, {})

      @table = Array.new(log2(@address_space).ceil) { [] }

      @nid_cache = {}
    end
    
    # Get the node in the table which is closest to <dest_addr>.
    def closest_node(dest_addr)
      @table.flatten.min do | a, b |
        distance(dest_addr, a.nid) <=> distance(dest_addr, b.nid)     
      end.nid
    end

    # Get a random node from the table.
    def random_node
      @table.flatten[rand(size)]
    end

    # Choose <num> random nodes from the table.  If there are not as many nodes
    # as were requested and duplicates are not allowed the response will all
    # nodes. If <allow_duplicates> is set to false then the result will not
    # contain the same node twice.
    def random_nodes(num_nodes, allow_duplicates = true)
      return @table.flatten  if num_nodes >= size

      nodes = []
      num_nodes.times do
        if allow_duplicates
          nodes << random_node
        else
          while(nodes.include?(node = random_node)); end
          nodes << node
        end
      end

      nodes
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
    # TODO: This is where policy decisions will be made about the placement
    # of nodes in the table and/or a cache etc...
    def old_store_peer(peer)
      return if has_nid?(peer.nid) || peer.nid == @nid

      @nid_cache[peer.nid] = true
      bin = log2(distance(@nid, peer.nid)).floor
      if @table[bin].size < @num_slots
        @table[bin] << peer
        @last_modified = @sim.time
      end
    end

    def store_peer(peer)
      return if has_nid?(peer.nid) || peer.nid == @nid

      @nid_cache[peer.nid] = true
      bin = log2(distance(@nid, peer.nid)).floor
      @table[bin].shift
      @table[bin] << peer
    end
    alias :<< :store_peer

    def bin_sizes
      @table.map {|i| i.size}
    end

    def each
      @table.flatten.each { | x | yield x }
    end

    private

    # Log base 2
    def log2(num)
      Math.log(num) / Math.log(2)
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
