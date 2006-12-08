module Spinneret   
  
  # A management class sitting on top of the link table.
  class LinkTable
    include Base
    include KeywordProcessor

    DEFAULT_MAX_PEERS = 25
    attr_accessor :max_peers

    def initialize(nid, args = {})
      @nid = nid
      @sim = GoSim::Simulation.instance
      @last_modified = 0

      params_to_ivars(args, {
        :max_peers => DEFAULT_MAX_PEERS
      })

      @nid_peers = {}
    end

    def peers
      @nid_peers.values
    end

    def nids
      @nid_peers.keys
    end
    
    # The total number of nodes in the table.
    def size
      @nid_peers.size
    end
    
    # Whether the table currently contains a specific address.
    def has_nid?(nid)
      @nid_peers.has_key?(nid)
    end

    # Whether the table currently contains a specific peer.
    def has_peer?(peer)
      @nid_peers.has_key?(peer.nid)
    end

    def get_peer(nid)
      @nid_peers[nid]
    end

    # Get the node in the table which is closest to <dest_addr>.
    def closest_peer(dest_nid)
      peers.min do | a, b |
        distance(dest_nid, a.nid) <=> distance(dest_nid, b.nid)     
      end
    end

    def closest_peers(dest_nid, n)
      peers.sort do |a,b| 
        distance(dest_nid, a.nid) <=> distance(dest_nid, b.nid)     
      end[0, n]
    end

    # Get a random node from the table.
    def random_peer
      peers[rand(size)]
    end

    # Choose <num> random nodes from the table.  If there are not as many nodes
    # as were requested and duplicates are not allowed the response will all
    # nodes. If <allow_duplicates> is set to false then the result will not
    # contain the same node twice.
    def random_peers(num_peers, allow_duplicates = true)
      return @nid_peers.values if num_peers >= size

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

    # The distance between two network addresses.
    def distance(x, y)
      @distance_func.call(x, y)
    end

    # Store an address in the table if it is new.
    def store_peer(peer)
      # Don't store repeats or ourself
      return if peer.nid == @nid

      # If we have already heard about this node check and possibly update the timestamp
      if has_peer?(peer)
        if peer.last_seen > @nid_peers[peer.nid].last_seen
          @nid_peers[peer.nid].last_seen = peer.last_seen
        end
      else
        peer.distance = Math::log2(distance(@nid, peer.nid))
        @nid_peers[peer.nid] = peer

        trim if @nid_peers.size > @max_peers
      end
    end
    alias :<< :store_peer

    # Trim based on only spacing
    # The nodes on the extreme ends always stay, and the node closest to its
    # two neighbors in the middle is booted.
    def trim
      sorted_peers = @nid_peers.values.sort {|a,b| a.distance <=> b.distance }
      #sorted_peers.each {|p| printf "%.2f, ", 2**p.distance }

      # First find the closest pair
      i_min = 0
      a_min = sorted_peers[0]
      b_min = sorted_peers[1]

      i = 1
      last_idx = sorted_peers.size - 1
      while(i != last_idx)
        a = sorted_peers[i]
        b = sorted_peers[i+1]

        if((b.distance - a.distance) < (b_min.distance - a_min.distance))
          a_min = a
          b_min = b
          i_min = i
        end
        i += 1
      end

      # Now pick which member of the pair needs to go
      # Favor nodes at the edge so we keep the extremes.
      if i_min == 0 # closest node
        @nid_peers.delete(b_min.nid)
      elsif (i_min + 1) == (sorted_peers.size - 1) # furthest node
        @nid_peers.delete(a_min.nid)
      else 
        da = a_min.distance - sorted_peers[i_min].distance
        db = sorted_peers[i_min + 1].distance - b_min.distance

        if da < db 
          @nid_peers.delete(a_min.nid)
        else
          @nid_peers.delete(b_min.nid)
        end
      end
    end

    # Peer iterator
    def each
      @nid_peers.each { |nid, peer| yield peer }
    end

    def to_s
      @nid_peers.map {|nid, peer| nid }.join(', ')
    end

    def inspect
      "#<Spinneret::LinkTable nid=#{@nid} peers: #{to_s}"
    end

  end

  # Just a container for keeping things like status information about a
  # specific peer in the link table.
  class Peer
    include Base

    attr_reader :addr, :nid
    attr_accessor :distance, :last_seen

    # We may also have algorithms that use things like rtt to make decisions.
    # What about a generic field that holds algorithm specific data?

    def initialize(addr, nid)
      @addr, @nid = addr, nid
      @distance = -1 # TODO: Decide if this needs to be address space

      seen
    end

    def seen
      @last_seen = GoSim::Simulation::instance.time
    end

    def to_s
      "nid=#{@nid}, addr=#{addr}, last_seen=#{@last_seen}"
    end

    def inspect
      "#<Spinneret::Peer #{to_s}"
    end
  end
end
