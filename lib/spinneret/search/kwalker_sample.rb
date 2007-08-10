module Spinneret
module Search
  module KWalkerSample
    def kwalk_sample(ttl, src_addr = @addr)
      return if !@topo.alive?(@addr)

      new_uid = SearchBase::get_new_uid()
      kwalker_query(new_uid, -1, src_addr, 1, ttl, :kwalker_sample_response)
    end

    # TODO: What do we want to do with search responses?
    def kwalker_sample_response(uid, peer_addr, ttl, found)
      log {"KWalker-sample got a query response..."}
      
      GoSim:::Data::EventCast::instance::publish(:kwalker_sample, peer_addr)

      @local_queries[uid] = true  # Supress negative logging
    end
  end
end
end
