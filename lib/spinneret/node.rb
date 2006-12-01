module Spinneret
  NeighborRequest = Struct.new(:src, :addr, :num)
  NeighborResponse = Struct.new(:src, :addr, :neighbors)

  class Node < GoSim::Net::Node
    NEIGHBOR_REQUEST_SIZE = 5
    
    attr_reader  :addr, :link_table

    def initialize(addr = nil,
                   start_peer = nil,
                   address_space = nil,
                   distance_func = nil)
      super()

#      log "New node id #{@nid}, with addr #{addr}"

      @addr = addr

      # TODO: Decide on and implement the passing through of parameters down
      # to the link table: slots, address space, distance_func...
      @link_table = LinkTable.new(addr)
      
      if start_peer
#        puts "making a node"
        @link_table.store_peer(start_peer)
        do_maintenance
      end
      set_timeout(10, true) { do_maintenance }
    end

    def handle_failed_packet(pkt)
      log "#{nid} - got failed packet! #{pkt.inspect}"
    end

    def handle_neighbor_request(pkt)
      send_packet(:neighbor_response, pkt.src,
                  NeighborResponse.new(@nid, @addr,
                                       @link_table.random_nodes(pkt.num)))
      @link_table.store_peer(Peer.new(pkt.src, pkt.addr))
    end

    def handle_neighbor_response(pkt)
      pkt.neighbors.each {|n| @link_table.store_peer(n)}
    end

    def handle_search(id)

    end

    private 

    def do_maintenance
      peers = @link_table.random_nodes(NEIGHBOR_REQUEST_SIZE)
      send_packet(:neighbor_request, peers.map { | p | p.nid },
                  NeighborRequest.new(@nid, @addr, NEIGHBOR_REQUEST_SIZE))
    end

  end
end
