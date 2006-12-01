module Spinneret
  NeighborRequest = Struct.new(:src, :num)
  NeighborResponse = Struct.new(:src, :neighbors)

  class Node < GoSim::Net::Node
    NEIGHBOR_REQUEST_SIZE = 5
    
    attr_reader  :addr, :link_table

    def initialize(addr = nil,
                   start_peer_addr = nil, 
                   address_space = nil,
                   distance_func = nil)
      super()

      @addr = addr

      # TODO: Decide on and implement the passing through of parameters down
      # to the link table: slots, address space, distance_func...
      @link_table = LinkTable.new(addr)
      
      if start_peer_addr
        puts "making a node"
        @link_table.store_addr(start_peer_addr)
        do_maintenance
      end
    end

    def handle_failed_packet(pkt)
      log "#{nid} - got failed packet! #{pkt.inspect}"
    end

    def handle_neighbor_request(pkt)
      send_packet(:neighbor_response, pkt.src,
                  NeighborResponse.new(@nid, 
                                       @link_table.random_nodes(pkt.num)))
    end

    def handle_neighbor_response(pkt)
      pkt.neighbors.each {|n| @link_table.store_addr n }
    end

    def handle_search(id)

    end

    private 

    def do_maintenance
      peers = @link_table.random_nodes(NEIGHBOR_REQUEST_SIZE)
      send_packet(:neighbor_request, peers,
                  NeighborRequest.new(@nid, NEIGHBOR_REQUEST_SIZE))
    end

  end
end
