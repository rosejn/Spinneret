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
      return if !@topo.alive?(@addr)

      new_uid = SearchBase::get_new_uid()
      kwalker_query(new_uid, dest_addr.to_i, src_addr, k, ttl)
    end

    def handle_kwalker_timeout(timer, uid)
      if @local_queries[uid] == false
        GoSim::Data::EventCast::instance::publish(:kwalker_search_finish, 
                                                  uid, false, 0)
      end
      @local_queries.delete(uid)
    end

    def kwalker_query(uid, query, src_addr = @addr, k = KW_NUM_WALKERS, ttl = KW_TTL)

      log {"node: #{@nid} - kwalker_query( q = #{query}, src = #{src_addr}, ttl = #{ttl})"}

      if(src_addr == @addr)
        @local_queries ||= []
        @local_queries[uid] = false
        set_timeout(KW_QUERY_TIMEOUT, false, uid, method(:handle_kwalker_timeout))
      end

      if(query == @nid)
        peer = @link_table.get_peer_by_addr(src_addr)
        peer.kwalker_response(uid, @addr, ttl)  unless peer.nil?
      elsif ttl == 0
        return
      else 
        # First check for a direct neighbor
        closest = @link_table.closest_peer(query)
        return if closest.nil?

        if closest.nid == query
          closest.kwalker_query(uid, query, src_addr, k, ttl - 1)
        else # Go random
          if(query == @addr) 
            @link_table.random_peers(k).each do |peer|
              peer.kwalker_query(uid, query, src_addr, k, ttl - 1)
            end
          else
            @link_table.random_peer.kwalker_query(uid, query, src_addr, k, ttl - 1)
          end
        end

      end
    end

    # TODO: What do we want to do with search responses?
    def kwalker_response(uid, peer_addr, ttl)
      log {"KWalker got a query response..."}
      if @local_queries[uid] == false
        GoSim::Data::EventCast::instance::publish(:kwalker_search_finish,
                                                  uid, true, ttl)
      end
      @local_queries[uid] = true
    end
  end
end
end
