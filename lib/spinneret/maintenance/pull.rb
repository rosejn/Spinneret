module Spinneret
module Maintenance

  NeighborRequest = Struct.new(:src, :nid, :num)
  NeighborResponse = Struct.new(:src, :nid, :neighbors)

  module Pull
    NEIGHBOR_REQUEST_SIZE = 5

    def do_maintenance
      peers = @link_table.random_nodes(NEIGHBOR_REQUEST_SIZE)
      send_packet(:neighbor_request, peers.map { | p | p.addr },
                  NeighborRequest.new(@addr, @nid, NEIGHBOR_REQUEST_SIZE))
    end

    def handle_neighbor_request(pkt)
      send_packet(:neighbor_response, pkt.src,
                  NeighborResponse.new(@addr, @nid,
                                       @link_table.random_nodes(pkt.num)))
      @link_table.store_peer(Peer.new(pkt.src, pkt.nid))
    end

    def handle_neighbor_response(pkt)
      pkt.neighbors.each {|n| @link_table.store_peer(n)}
    end

  end

end
end
