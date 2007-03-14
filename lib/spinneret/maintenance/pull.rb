module Spinneret
module Maintenance
  module Pull
    NeighborRequest = Struct.new(:src, :nid, :num)
    NeighborResponse = Struct.new(:src, :nid, :neighbors)

    NUM_NEIGHBOR_REQUESTS = 1

    def do_maintenance
      peers = @link_table.random_peers(NUM_NEIGHBOR_REQUESTS)
      peers.each do |peer|
        d = peer.neighbor_request(@addr, @nid, @config.maintenance_size - 1)
        d.add_callback {|peers| peers.each {|p| @link_table.store_peer(n)}}
      end

    end

    def neighbor_request(src_addr, src_nid, req_size)
      @link_table.store_peer(src_addr)
      @link_table.random_peers(req_size)
    end
  end

end
end
