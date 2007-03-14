module Spinneret
module Maintenance
  module Push
    NeighborPush = Struct.new(:src, :nid, :neighbors)

    NUM_NEIGHBOR_REQUESTS = 1

    def do_maintenance
      addrs = @link_table.random_peers(@config.maintenance_size).map {|p| p.addr}
      send_peers = @link_table.random_peers(NUM_NEIGHBOR_REQUESTS)
      send_peers.each do |peer|
        peer.neighbor_push(@addr, @nid, addrs)
      end
    end

    def neighbor_push(src_addr, src_nid, addrs)
      addrs.push(src_addr).each {|addr| @link_table.store_peer(addr)}
    end
  end
end
end
