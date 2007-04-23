module Spinneret
module Search

  JOIN_TTL          = 20

  module JoinQuery
    def run_join_query(id, start_addr)
#     GoSim::Data::DataSet[:dht_search].log(:new, @uid, dest_addr, nil, @nid)
      peer = @link_table.store_peer(start_addr)
      while(ttl > 0)
        peers = peer.join_query(query)
        peers.each { | p | @link_table.store_peer(p.addr) }

        break if !closer?(id, peers[0])

        peer = peers[0]

        ttl -= 1
      end
    end

    # Do a logarithmic query where at each hop we jump to the closest node
    # possible in the current link table.
    def join_query(query, peer, ttl = JOIN_TTL)
      log "node: #{@nid} - join_query( q = #{query})"

      return @link_table.closest_peers(query, 3)
    end

    def closer?(query, peer)
      @link_table.distance(query, peer.nid) < @link_table.distance(@nid, query)
    end

  end
end
end

