module Spinneret
  NeighborRequest = Struct.new(:src, :num)
  NeighborResponse = Struct.new(:src, :neighbors)

  class Node < GoSim::Net::Node
    DEFAULT_ADDRESS_SPACE = 10000
    NEIGHBOR_REQUEST_SIZE = 5
    
    attr_reader :link_table

    def initialize(id = nil,
                   start_peer_addr = nil, 
                   distance_func = nil, 
                   address_space = DEFAULT_ADDRESS_SPACE)
      super(id)

      @addr_cache = {}
      @address_space = address_space
      @link_table = Array.new(log2(@address_space).ceil) { [] }

      if distance_func
        @distance_func = distance_func 
      else
        @distance_func = method(:default_distance)
      end

      if start_peer_addr
        puts "making a node"
        store_address(start_peer_addr)
        do_maintenance
      end
    end

    def addr
      @nid
    end

    # Get the node in the table which is closest to <dest_addr>.
    def closest_node(dest_addr)
      @link_table.flatten.min {|a, b| distance(dest_addr, a) <=> distance(dest_addr, b) }
    end

    # Get a random node from the table.
    def random_node
      @link_table.flatten[rand(size)]
    end

    # Choose <num> random nodes from the table.  If there are not as many nodes
    # as were requested and duplicates are not allowed the response will all
    # nodes.
    def random_nodes(num_nodes, allow_duplicates = true)
      return @link_table.flatten if num_nodes >= size

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

    def size
      @link_table.flatten.size
    end

    def distance(x, y)
      @distance_func.call(x, y)
    end

    def handle_failed_packet(pkt)
      log "#{nid} - got failed packet! #{pkt.inspect}"
    end

    def handle_neighbor_request(pkt)
      send_packet(:neighbor_response, pkt.src, pkt.num,
                  NeighborResponse.new(@nid, random_nodes(pkt.num)))
    end

    def handle_neighbor_response(pkt)
      pkt.neighbors.each {|n| store_address n }
    end

    def handle_search(id)

    end

    private 

    def store_address(addr)
      puts "#{@nid}: storing addr #{addr}"
      @addr_cache[addr] = true
      bin = log2(distance(@nid, addr)).floor
      @link_table[bin] = Peer.new(addr) if @link_table[bin].nil?
      puts @link_table.inspect
    end

    def log2(num)
      Math.log(num) / Math.log(2)
    end

    def do_maintenance
      peers = random_nodes(NEIGHBOR_REQUEST_SIZE)
      addrs = peers.map {|p| p.addr }
      send_packet(:neighbor_request, addrs,
                  NeighborRequest.new(@nid, NEIGHBOR_REQUEST_SIZE))
    end

    def default_distance(x, y)
      d1 = (y - x).abs
      min = (y < x ? y : x)
      max = (y >= x ? y : x)
      d2 = (@address_space - max) + min

      return (d1 < d2 ? d1 : d2)
    end
  end

  class Peer
    attr_reader :addr

    def initialize(addr)
      @addr = addr
    end
  end
end
