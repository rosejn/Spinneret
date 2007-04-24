module Spinneret
module Maintenance
  module PushPull
    NeighborRequest = Struct.new(:src, :nid, :neighbors)
    NeighborResponse = Struct.new(:src, :nid, :neighbors)

    NUM_NEIGHBOR_REQUESTS = 1

    def do_maintenance
      #puts "#{@sim.time} #{@nid} doing maintenance"
      peers = @link_table.random_peers(NUM_NEIGHBOR_REQUESTS)
      peers.each do |peer|
        addrs = @link_table.random_peers(@config.maintenance_size / 2).map {|p| p.addr }

        peer.neighbor_request(@addr, addrs).add_callback do |addrs| 
          addrs.each {|p| @link_table.store_peer(p) } 
        end
      end
    end

    def neighbor_request(src_addr, addrs)
      log {"#{@nid} - got neighbor request from #{src_addr}"}
      @link_table.store_peer(src_addr)
      n = @link_table.random_peers(@config.maintenance_size / 2).map {|p| p.addr }
      addrs.each { | a | @link_table.store_peer(a) }
      return n
    end
  end

end
end
