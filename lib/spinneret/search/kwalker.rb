module Spinneret
module Search
  module KWalker
    KW_NUM_WALKERS   = 32
    KW_TTL           = 20
    KW_QUERY_TIMEOUT = 30000
    KW_RESPONSE      = :kwalker_response

    def search_kwalk(dest_addr, src_addr = @addr, 
                     k = KW_NUM_WALKERS, ttl = KW_TTL,
                     response_func = KW_RESPONSE)
      return if !@topo.alive?(@addr)

      # Setup state keeping for reporting success or failure
      new_uid = SearchBase::get_new_uid()

      @local_queries ||= []
      @local_queries[new_uid] = false
      set_timeout(KW_QUERY_TIMEOUT, false, new_uid, 
                  method(:handle_kwalker_timeout))

      k.times do
        kwalker_query(new_uid, dest_addr.to_i, src_addr, ttl, response_func)
      end
    end

    def handle_kwalker_timeout(timer, uid)
      if @local_queries[uid] == false
        GoSim::Data::EventCast::instance::publish(:kwalker_search_finish, 
                                                  uid, false, 0)
      end
      @local_queries.delete(uid)
    end

    def kwalker_query(uid, query, src_addr = @addr, ttl = KW_TTL, 
                      response_func = KW_RESPONSE)

      log {"#{@nid}: kwalker_query(q = #{query}, src = #{src_addr}, ttl = #{ttl})"}

      if(query == @nid)
        peer = @link_table.get_peer_by_addr(src_addr)
        peer.send(response_func, uid, @addr, ttl, true)  unless peer.nil?
      elsif ttl == 0
        peer = @link_table.get_peer_by_addr(src_addr)
        peer.send(response_func, uid, @addr, ttl, false) unless peer.nil?
      else 
        # First check for a direct neighbor
        closest = @link_table.closest_peer(query)
        return if closest.nil?

        if closest.nid == query
          closest.kwalker_query(uid, query, src_addr, ttl - 1, response_func)
        else # Go random
          peer = @link_table.random_peer
          peer.kwalker_query(uid, query, src_addr, ttl - 1, response_func)
        end

      end
    end

    # TODO: What do we want to do with search responses?
    def kwalker_response(uid, peer_addr, ttl, found)
      log {"KWalker got a query response..."}

      if @local_queries[uid] == false && found
        GoSim::Data::EventCast::instance::publish(:kwalker_search_finish,
                                                  uid, true, ttl)
        @local_queries[uid] = true
      end
    end

  end
end
end
