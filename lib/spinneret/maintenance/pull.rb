module Spinneret
module Maintenance

  NeighborRequest = Struct.new(:src, :addr, :num)
  NeighborResponse = Struct.new(:src, :addr, :neighbors)

  module Pull
    NEIGHBOR_REQUEST_SIZE = 5

    def do_maintenance
      peers = @link_table.random_nodes(NEIGHBOR_REQUEST_SIZE)
      send_packet(:neighbor_request, peers.map { | p | p.nid },
                  NeighborRequest.new(@nid, @addr, NEIGHBOR_REQUEST_SIZE))
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

  end

end
end
