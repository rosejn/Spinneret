module Spinneret
module Search
  KWalkerQuery = SearchBase.new(:src_addr, :query, :ttl)
  KWalkerResponse = SearchBase.new(:src_addr, :src_id, :ttl)

  module KWalker
    KW_NUM_WALKERS   = 32
    KW_TTL           = 20
    KW_QUERY_TIMEOUT = 30000

    def handle_search_kwalk(dest_addr, src_addr = @addr, 
                            k = KW_NUM_WALKERS, ttl = KW_TTL)
      new_uid = SearchBase::get_new_uid()
      kwalker_query(new_uid, dest_addr.to_i, src_addr, k, ttl)
    end

    def kwalker_query(uid, query, src_addr = @addr, 
                      k = KW_NUM_WALKERS,
                      ttl = KW_TTL)

      log "node: #{@nid} - kwalker_query( q = #{query}, src = #{src_addr}, ttl = #{ttl})"

      if(src_addr == @addr)
        @local_queries ||= []
        @local_queries[uid] = false
        set_timeout(KW_QUERY_TIMEOUT) {
          if @local_queries[uid] == false
            Analyzer::instance::failed_kwalk_search(uid)
          end
          @local_queries.delete(uid)
        }
      end

      if(query == @nid)
        send_packet(:kwalker_response, src_addr, 
                    KWalkerResponse.new(uid, @addr, @nid, ttl - 1))
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
                    KWalkerQuery.new(uid, src_addr, query, ttl - 1))
      end
    end

    def handle_kwalker_query(pkt)
      kwalker_query(pkt.uid, pkt.query, pkt.src_addr, 1, pkt.ttl)
    end

    # TODO: What do we want to do with search responses?
    def handle_kwalker_response(pkt)
      log "KWalker got a query response..."
      if @local_queries[pkt.uid] == false
        Analyzer::instance::successful_kwalk_search(pkt.uid)
      end
      @local_queries[pkt.uid] = true
    end
  end
end
end
