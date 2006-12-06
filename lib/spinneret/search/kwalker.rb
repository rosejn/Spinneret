module Spinneret
module Search
  KWalkerQuery = Struct.new(:src_addr, :query, :ttl)
  KWalkerResponse = Struct.new(:src_addr, :src_id, :ttl)

  module KWalker
    KW_NUM_WALKERS = 32
    KW_TTL         = 20

    def handle_search_kwalk(dest_addr)
      kwalker_query(dest_addr.to_i)
    end

    def kwalker_query(query, src_addr = @addr, 
                      k = KW_NUM_WALKERS,
                      ttl = KW_TTL)

      log "node: #{@nid} - kwalker_query( q = #{query}, src = #{src_addr}, ttl = #{ttl})"

      if(query == @nid)
        send_packet(:kwalker_response, src_addr, 
                    KWalkerResponse.new(@addr, 
                                        @nid, 
                                        ttl - 1))
      elsif ttl == 0
       return

      else 
        
        # First check for a direct neighbor
        closest = @link_table.closest_peer(query)
        return if closest.nil?
        if closest.nid == query
          dest = closest.addr
        else # Go random 
          dest = @link_table.random_peers(k).map {|p| p.addr }
        end

        log "forwarding query to dest: #{dest}"
        send_packet(:kwalker_query, dest, 
                    KWalkerQuery.new(src_addr, query, ttl - 1))
      end
    end

    def handle_kwalker_query(pkt)
      kwalker_query(pkt.query, pkt.src_addr, 1, pkt.ttl)
    end

    # TODO: What do we want to do with search responses?
    def handle_kwalker_response(pkt)
      log "KWalker got a query response..."
    end
  end
end
end
