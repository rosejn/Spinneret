module Spinneret
module Maintenance
  module Opportunistic
    OpPacket = Struct.new(:neighbors, :args)

    def opportunistic_setup_aspects
#=begin
      insert_send_aspect do | method, outgoing |
        if((@config.maintenance_opportunistic_alwayson || @link_table.converged?) &&
           method != :neighbor_request)
        then
          n = @link_table.random_peers(@config.maintenance_size).map {|p|p.addr}
          OpPacket.new(n, outgoing)
        else
          outgoing
        end
      end

      insert_receive_aspect do | method, incoming |
        if method != :neighbor_request && incoming.class == OpPacket 
          incoming.neighbors.each {|p| @link_table.store_peer(p)}  if alive?
          incoming.args
        else
          incoming
        end
      end

#=end
    end

  end
end
end
