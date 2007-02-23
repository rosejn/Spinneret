module Spinneret
module Maintenance
  module Push
    NeighborPush = Struct.new(:src, :nid, :neighbors)

    NUM_NEIGHBOR_REQUESTS = 1

    def do_maintenance
      peers = @link_table.random_peers(@config.maintenance_size)
      send_peers = @link_table.random_peers(NUM_NEIGHBOR_REQUESTS)
      send_packet(:neighbor_push, send_peers.map{ | p | p.addr },
                  NeighborPush.new(@addr, @nid, peers))
    end

    def handle_neighbor_push(pkt)
      pkt.neighbors.each { | n | @link_table.store_peer(n)}
      @link_table.store_peer(Peer.new(pkt.src, pkt.nid))
    end

  end

end
end
