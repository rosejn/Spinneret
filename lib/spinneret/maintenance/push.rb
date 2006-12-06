module Spinneret
module Maintenance
  module Push
    NeighborPush = Struct.new(:src, :nid, :neighbors)

    NEIGHBOR_PUSH_SIZE = 5

    def do_maintenance
      peers = @link_table.random_peers(NEIGHBOR_PUSH_SIZE)
      send_packet(:neighbor_response, pkt.src,
                  NeighborPush.new(@addr, @nid, peers))
    end

    def handle_neighbor_push(pkt)
      pkt.neighbors.each {|n| @link_table.store_peer(n)}
    end

  end

end
end
