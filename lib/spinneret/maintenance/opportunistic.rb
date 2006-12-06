module Spinneret
module Maintenance
  module Opportunistic
    OP_WRAP_SIZE = 5

    OpHeader = Struct.new(:src, :nid, :neighbors, :ptype, :pkt)

    def do_maintenance
    end

    def send_packet(id, receivers, pkt)
      peers = @link_table.random_peers(OP_WRAP_SIZE)
      super(:op_header, receivers, OpHeader.new(@addr, @nid, peers, id, pkt))
    end

    def handle_op_header(header)
      header.neighbors.each {|n| @link_table.store_peer(n)}

      # Now call the wrapped handler
      send(("handle_" + header.ptype).to_sym, header.pkt)
    end
  end
end
end
