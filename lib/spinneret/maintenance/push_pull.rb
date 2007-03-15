module Spinneret
module Maintenance
  module PushPull
    NeighborRequest = Struct.new(:src, :nid, :neighbors)
    NeighborResponse = Struct.new(:src, :nid, :neighbors)

    NUM_NEIGHBOR_REQUESTS = 1

    def do_maintenance
      peers = @link_table.random_peers(NUM_NEIGHBOR_REQUESTS)
      peers.each do |peer|
        addrs = @link_table.random_peers(@config.maintenance_size / 2).map {|p| p.addr }

        d = peer.neighbor_request(@addr, addrs)

        d.add_callback do |addrs| 
          addrs.each {|p| @link_table.store_peer(p) } 
        end
      end
    end

    def neighbor_request(src_addr, peers)
      log {"#{@nid} - got neighbor request from #{src_addr}"}
      @link_table.store_peer(src_addr)
      @link_table.random_peers(@config.maintenance_size / 2).map {|p| p.addr }
    end
  end

end
end
