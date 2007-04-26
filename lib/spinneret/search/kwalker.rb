module Spinneret
module Search
  KWalkerQuery = SearchBase.new(:src_addr, :query, :ttl)
  KWalkerResponse = SearchBase.new(:src_addr, :src_id, :ttl)

  module KWalker
    KW_NUM_WALKERS   = 32
    KW_TTL           = 20
    KW_QUERY_TIMEOUT = 30000

    def search_kwalk(dest_addr, src_addr = @addr, 
                            k = KW_NUM_WALKERS, ttl = KW_TTL)
      new_uid = SearchBase::get_new_uid()
      kwalker_query(new_uid, dest_addr.to_i, src_addr, k, ttl)
    end

    def kwalker_query(uid, query, src_addr = @addr, 
                      k = KW_NUM_WALKERS,
                      ttl = KW_TTL, orig = true)

      log {"node: #{@nid} - kwalker_query( q = #{query}, src = #{src_addr}, ttl = #{ttl})"}

      if(orig == true)
        @local_queries ||= []
        @local_queries[uid] = false
        set_timeout(KW_QUERY_TIMEOUT) {
          if @local_queries[uid] == false
            GoSim::Data::EventCast::instance::publish(:kwalker_search_finish,
                                                      uid, false, 0)
          end
          @local_queries.delete(uid)
        }
      end

      if(query == @nid)
        peer = @link_table.get_peer_by_addr(src_addr)
        peer.kwalker_response(uid, @addr, ttl)
      elsif ttl == 0
        return
      else 
        # First check for a direct neighbor
        closest = @link_table.closest_peer(query)
        return if closest.nil?

        if closest.nid == query
          closest.kwalker_query(uid, query, src_addr, ttl - 1)
        else # Go random 
          @link_table.random_peers(k).each do |peer|
            peer.kwalker_query(uid, query, src_addr, ttl - 1)
          end
        end

      end
    end

    # TODO: What do we want to do with search responses?
    def kwalker_response(uid, peer_addr, ttl)
      @local_queries ||= []

      log {"KWalker got a query response..."}
      if @local_queries[uid] == false
        GoSim::Data::EventCast::instance::publish(:kwalker_search_finish,
                                                  uid, false, ttl)
      end
      @local_queries[uid] = true
    end
  end
end
end
