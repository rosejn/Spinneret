require 'monitor'
require 'thread'

require 'gsl'

#require 'breakpoint'

module Spinneret   

  # A management class sitting on top of the link table.
  class LinkTable
    include Base
    include KeywordProcessor

    attr_reader :nid

    # Create a new LinkTable.
    def initialize(node)
      @config = Configuration.instance.link_table

      @node = node
      @nid = @node.nid || random_id 
      @sim = GoSim::Simulation.instance
      @last_modified = 0

      @config.distance_func ||= DistanceFuncs.sym_circular(@config.address_space)

      @table_lock = Monitor.new
      @nid_peers = {}
    end

    # Remove all peers from the link table
    def clear
      @nid_peers.clear
    end

    # Return a random virtual network id
    def random_id
      @@ids ||= {}
      while(@@ids.has_key?(id = rand(@config.address_space)))
      end
      @@ids[id] = true
      return id
    end

    # Array of peers
    #
    # NOTE: This is not a thread-safe method.
    def peers
      @table_lock.synchronize { @nid_peers.values }
    end

    # Array of node ids
    def nids
      @table_lock.synchronize { @nid_peers.keys }
    end

    # The total number of nodes in the table.
    def size
      @table_lock.synchronize { @nid_peers.size }
    end

    # Whether the table currently contains a specific nid.
    def has_nid?(nid)
      @table_lock.synchronize { @nid_peers.has_key?(nid) }
    end

    # Whether the table currently contains a specific peer.
    def has_peer?(peer)
      @table_lock.synchronize { @nid_peers.has_key?(peer.nid) }
    end

    # Get a peer by node id
    def get_peer(nid)
      @table_lock.synchronize { @nid_peers[nid] }
    end

    def get_peer_by_addr(addr)
      store_peer(addr)
    end

    # Peer iterator
    def each
      @table_lock.synchronize { @nid_peers.each { |nid, peer| yield peer } }
    end

    # String representation (list of node ids)
    RED = "\e[31m"
    CLEAR = "\e[0m"
    def to_s
      str = ""
      peers = peers_by_distance()
      smallest = find_smallest_dist()
      (peers.length - 1).times do | idx | 
        str += RED  if peers[idx].nid == smallest
      str += peers[idx].nid.to_s
      str += CLEAR  if peers[idx].nid == smallest
      str += " <-- " +
        sprintf("%.3f", (peers[idx + 1].distance - peers[idx].distance)) + " --> "
      end
      str += peers[peers.length - 1].nid.to_s
      return str
    end

    def inspect
      "#<Spinneret::LinkTable nid=#{@nid} peers: #{to_s}"
    end

    # Get the node in the table which is closest to <dest_nid>.
    def closest_peer(dest_nid)
      @table_lock.synchronize do
        peers.min do | a, b |
          distance(dest_nid, a.nid) <=> distance(dest_nid, b.nid)     
        end
      end
    end

    # Get the <n> closest peers to <dest_nid>
    def closest_peers(dest_nid, n)
      @table_lock.synchronize do
        peers.sort do |a,b| 
          distance(dest_nid, a.nid) <=> distance(dest_nid, b.nid)     
        end[0, n]
      end
    end

    # Get a random node from the table.
    def random_peer
      @table_lock.synchronize { peers[rand(size)] }
    end

    # Choose <num> random nodes from the table.  If there are not as many nodes
    # as were requested and duplicates are not allowed the response will all
    # nodes. If <allow_duplicates> is set to false then the result will not
    # contain the same node twice.
    def random_peers(num_peers, allow_duplicates = false)
      peers = nil
      @table_lock.synchronize { peers = @nid_peers.values if num_peers >= size }
      return peers unless peers.nil?

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
    #
    # [*x*] A node id
    # [*y*] A node id
    def distance(x, y)
      @config.distance_func.call(x, y)
    end

    # Store an address in the table if it is new.
    #
    # [*peer*] The peer to add to the table
    def store_peer(peer_addr)
      log {"storing #{peer_addr} at node #{@node.addr}"}
      return nil if peer_addr == @node.addr # Don't store ourself
#      return nil if @nid == @node.nid # Don't store ourself

      peer = Peer.new(@node, peer_addr)
      return nil if peer.nid.nil?

      # If we have already heard about this node check and possibly update the timestamp
      if has_peer?(peer)
        @table_lock.synchronize do
          if peer.last_seen > @nid_peers[peer.nid].last_seen
            @nid_peers[peer.nid].last_seen = peer.last_seen
          end
        end
        peer = @nid_peers[peer.nid]
      else
        begin
          peer.distance = Math::log2(distance(@nid, peer.nid))

          if(peer.distance < 0)
            raise Exception.new("DistanceNotPositive")
          end
        rescue Exception => e
          puts "#{@node.addr - @nid}:Could not compute distance from ourself(#{@nid}) to (#{peer.nid})"
          puts "Peer-> #{peer.inspect}" 
          puts "Self-> #{self.inspect}"
          raise e
        end

        @table_lock.synchronize do
          @nid_peers[peer.nid] = peer

          GoSim::Data::DataSet[:link].log(:add, @nid, peer.nid)
          trim if @nid_peers.size > @config.max_peers
        end
      end

      peer
    end

    # Remove a peer from the table
    #
    # [*id*] The id of the peer to be removed
    def remove_peer(id)
      @table_lock.synchronize { @nid_peers.delete(id) }
      GoSim::Data::DataSet[:link].log(:remove, @nid, id)
    end

    # Array of peers sorted by distance from me.
    def peers_by_distance
      @nid_peers.values.sort {|a,b| a.distance <=> b.distance }
    end

    # Find the sum of squares of our current distances to the ideal table
    def sum_of_squares
      d = 0
      pbd = peers_by_distance
      @config.max_peers.times do |index|
        if pbd[index]
          d += (@ideal_table[index] - pbd[index].distance) ** 2
        else
          d += @ideal_table[index] ** 2
        end
      end
      d / @config.max_peers
    end

    private

    def find_smallest_dist
      return nil  if @nid_peers.length < 2

      sorted_peers = peers_by_distance()

      i_min = 1
      v_min = 2**31

      i = 1
      last_idx = sorted_peers.size - 1
      while(i != last_idx)
        a = sorted_peers[i-1]
        b = sorted_peers[i]
        c = sorted_peers[i+1]

        dist = (b.distance - a.distance) + (c.distance - b.distance)

        if(dist < v_min)
          i_min = i
          v_min = dist
        end
        i += 1
      end

      return sorted_peers[i_min].nid
    end

    # Trim based on only spacing
    # The nodes on the extreme ends always stay, and the node closest to its
    # two neighbors in the middle is booted.
    #
    # NOTE: This method is not threadsafe
    def trim
      smallest = find_smallest_dist

      GoSim::Data::DataSet[:link].log(:remove, @nid, smallest)
      @nid_peers.delete(smallest)
    end

    public

    def line_fit
      sorted_peers = peers_by_distance()

      x = Vector.alloc(Array.new(sorted_peers.length) { | x | x })
      y = []
      sorted_peers.each do | peer |
        y << peer.distance
      end

      y = Vector.alloc(y)

      return GSL::Fit::linear(x, y)
    end

    def density
      return 1.0/2.0**line_fit[0]
    end

    def normal_fit
      log {"#{@nid} - normal_fit size=#{size}"}
      sorted_peers = peers_by_distance()

      samples = []
      (sorted_peers.length - 1).times do | idx |
        samples << sorted_peers[idx + 1].distance - sorted_peers[idx].distance
      end

      if(samples.length > 0)
        return samples.normal_fit()
      else
        return [0.0, 0.0]
      end
    end
  end

  # Just a container for keeping things like status information about a
  # specific peer in the link table.
  class Peer < GoSim::Net::Peer
    include Base

    attr_reader :nid
    attr_accessor :distance, :last_seen

    def initialize(local_node, remote_addr)
      super

      @nid = @remote_node.nid if @remote_node
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
