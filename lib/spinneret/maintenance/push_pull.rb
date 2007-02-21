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
                                      @link_table.random_peers(@config.maintenance_size)))
    end

    def handle_neighbor_request(pkt)
      send_packet(:neighbor_response, pkt.src,
                  NeighborResponse.new(@addr, @nid,
                                       @link_table.random_peers(@config.maintenance_size)))
      @link_table.store_peer(Peer.new(pkt.src, pkt.nid))
      handle_neighbor_response(pkt)
    end

    def handle_neighbor_response(pkt)
#      printf("@%d\n", @sim.time) if @addr == 1641
#      printf("before: %s\n", @link_table)  if @nid == 1641
      pkt.neighbors.each {|n| @link_table.store_peer(n)}
#      printf("after: %s\n", @link_table)  if @nid == 1641
    end

  end

end
end
