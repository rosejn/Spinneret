module Spinneret
module Maintenance
  module Opportunistic
    OpHeader = Struct.new(:src, :nid, :neighbors, :ptype, :pkt)

    def do_maintenance
    end

    def send_packet(id, receivers, pkt)
      peers = @link_table.random_peers(@maintenance_size)
      super(:op_header, receivers, OpHeader.new(@addr, @nid, peers, id, pkt))
    end

    def handle_op_header(header)
      header.neighbors.each {|n| @link_table.store_peer(n)}

      # Now call the wrapped handler
      send(("handle_" + header.ptype.to_s).to_sym, header.pkt)
    end
  end
end
end
