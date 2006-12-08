module Spinneret
module Maintenance
  module PushPull
    NeighborRequest = Struct.new(:src, :nid, :neighbors)
    NeighborResponse = Struct.new(:src, :nid, :neighbors)

    NUM_NEIGHBOR_REQUESTS = 1

    def do_maintenance
      peers = @link_table.random_peers(NUM_NEIGHBOR_REQUESTS)
      send_packet(:neighbor_request, peers.map { | p | p.addr },
                  NeighborRequest.new(@addr, @nid,
                                      @link_table.random_peers(@maintenance_size)))
    end

    def handle_neighbor_request(pkt)
      send_packet(:neighbor_response, pkt.src,
                  NeighborResponse.new(@addr, @nid,
                                       @link_table.random_peers(@maintenance_size)))
      @link_table.store_peer(Peer.new(pkt.src, pkt.nid))
      handle_neighbor_response(pkt)
    end

    def handle_neighbor_response(pkt)
      pkt.neighbors.each {|n| @link_table.store_peer(n)}
    end

  end

end
end
