module Spinneret
module Search
#  DHTQuery = SearchBase.new(:src_addr, :query, :ttl)
#  DHTBurstQuery = SearchBase.new(:src_addr, :query, :ttl)
#  DHTResponse = SearchBase.new(:src_addr, :src_id, :ttl)

  DHT_TTL          = 20
  DHT_BURST_TTL    = 2
  DHT_BURST_SIZE   = 4
  DHT_BURST_CHANCE = 0.75
  DHT_QUERY_TIMEOUT = 30000

  module DHT
    def search_dht(dest_addr)
      return if !@topo.alive?(@addr)

      uid = SearchBase::get_new_uid
      GoSim::Data::DataSet[:dht_search].log(:new, uid, dest_addr, nil, @nid)
      dht_query(uid, dest_addr.to_i) 
    end

    def handle_dht_timeout(timer, uid)
      if @local_queries[uid] == false
        GoSim::Data::EventCast::instance::publish(:dht_search_finish, 
                                                  uid, false, 0)
      end
      @local_queries.delete(uid)
    end

    # Do a logarithmic query where at each hop we jump to the closest node
    # possible in the current link table.
    def dht_query(uid, query, src_addr = @addr, immed_src = nil, ttl = DHT_TTL)
      log "node: #{@nid} - dht_query( q = #{query})"
      if !immed_src.nil?
        GoSim::Data::DataSet[:dht_search].log(:update, uid, query, immed_src, @nid) 
      end

      # Are we a local query?
      if(src_addr == @addr)
        @local_queries ||= []
        @local_queries[uid] = false
        set_timeout(DHT_QUERY_TIMEOUT, false, uid, method(:handle_dht_timeout))
      end

      unless us_or_dead?(uid, query, src_addr, ttl)
        # Find closest neighbor and figure out whether we burst or jump.
        closest = @link_table.closest_peer(query)

        return if closest.nil? # Can't do anything if we don't have peers...

        if closer?(query, closest) # Jump
          log {"#{@nid} - dht query: #{query} to dest: #{closest.nid}"}
          closest.dht_query(uid, query, src_addr, @nid, ttl - 1)
          
        # Start the burst query
        else 
          dht_burst_query(uid, query, src_addr, immed_src, DHT_BURST_TTL)
        end
      end
    end

    # Do a localized, probabalistic burst flood to get over local minima close
    # to the query target.
    def dht_burst_query(uid, query, src_addr, immed_src, ttl)
      log {"node: #{@nid} - dht_burst_query( q = #{query})"}

      GoSim::Data::DataSet[:dht_search].log(:update, uid, query, immed_src, @nid) 

      unless us_or_dead?(uid, query, src_addr, ttl)
        peers = @link_table.closest_peers(query, DHT_BURST_SIZE)
        if peers.empty?
          log {"#{@nid}: no peers to forward DHT search uid: #{uid}"}
          return
        end
       
        # If one of our immediate neighbors is the target go straight there.
        if @link_table.has_nid?(query)
          dest = @link_table.get_peer(query)

          log {"#{@nid} - dht direct burst query: #{query} to dest: #{query}"}
          dest.dht_burst_query(uid, query, src_addr, @nid, ttl - 1)

        # Otherwise we follow the burst chance
        else
          peers = @link_table.closest_peers(query, DHT_BURST_SIZE)
          return if peers.empty?

          peers = peers.select { rand <= DHT_BURST_CHANCE }
          return if peers.empty?

          log {"#{@nid} - dht burst query: #{query} to dest: #{peers.map {|p| p.nid }.join(', ')}"}
          peers.each {|p| p.dht_burst_query(uid, query, src_addr, @nid, ttl - 1) }
        end
      end
    end

    def us_or_dead?(uid, query, src_addr, ttl)
      if(query == @nid)
        log {"#{@nid} - query: #{query} successful!"}
        dest = @link_table.get_peer_by_addr(src_addr)
        log {"DHT Search successfull for #{@nid} (#{uid})"}
        dest.dht_response(uid, @nid, DHT_TTL - ttl)  unless dest.nil?
        true

      elsif ttl == 0
        log {"#{@nid} - query: #{query} ttl reached 0!"}
        true
      else
        false
      end
    end

    def closer?(query, peer)
      @link_table.distance(query, peer.nid) < @link_table.distance(@nid, query)
    end

    # TODO: What do we want to do with search responses?
    def dht_response(uid, peer_nid, ttl)
      log {"DHT got a query response..."}
      if @local_queries[uid] == false
        GoSim::Data::EventCast::instance::publish(:dht_search_finish, uid, true, ttl)
      end
      @local_queries[uid] = true
    end
  end
end
end

