module Spinneret
module Search
  DHTQuery = SearchBase.new(:src_addr, :query, :ttl)
  DHTBurstQuery = SearchBase.new(:src_addr, :query, :ttl)
  DHTResponse = SearchBase.new(:src_addr, :src_id, :ttl)

  DHT_TTL          = 20
  DHT_BURST_TTL    = 4
  DHT_BURST_SIZE   = 4
  DHT_BURST_CHANCE = 0.6

  module DHT
    def handle_search_dht(dest_addr)
      new_uid = SearchBase::get_new_uid()
      Analyzer::instance::add_search_trial(new_uid)
      dht_query(new_uid, dest_addr.to_i) 
    end

    # Do a logarithmic query where at each hop we jump to the closest node
    # possible in the current link table.
    def dht_query(uid, query, src_addr = @addr, ttl = DHT_TTL)
      log "node: #{@nid} - dht_query( q = #{query})"

      unless us_or_dead?(uid, query, src_addr, ttl)
        # Find closest neighbor and figure out whether we burst or jump.
        closest = @link_table.closest_peer(query)

        return if closest.nil? # Can't do anything if we don't have peers...

        if closer?(query, closest) # Jump
          dest = closest.addr
          log "#{@nid} - dht query: #{query} to dest: #{closest.nid}"
          send_packet(:dht_query, dest, 
                      DHTQuery.new(uid, src_addr, query, ttl))
         
        # Start the burst query
        else 
          dht_burst_query(uid, query, src_addr, DHT_BURST_TTL)
        end
      end
    end

    # Do a localized, probabalistic burst flood to get over local minima close
    # to the query target.
    def dht_burst_query(uid, query, src_addr, ttl)
      log "node: #{@nid} - dht_query( q = #{query})"

      unless us_or_dead?(uid, query, src_addr, ttl)
        peers = @link_table.closest_peers(query, DHT_BURST_SIZE)
        return if peers.empty?
       
        # If one of our immediate neighbors is the target go straight there.
        if @link_table.has_nid?(query)
          dest = [@link_table.get_peer(query).addr]

          log "#{@nid} - dht direct burst query: #{query} to dest: #{query}"
          send_packet(:dht_burst_query, dest,
                      DHTBurstQuery.new(uid, src_addr, query, ttl - 1))

        # Otherwise we follow the burst chance
        else
          peers = @link_table.closest_peers(query, DHT_BURST_SIZE)
          return if peers.empty?

          peers = peers.select { rand <= DHT_BURST_CHANCE }
          return if peers.empty?

          dest = peers.map {|p| p.addr }
          log "#{@nid} - dht burst query: #{query} to dest: #{peers.map {|p| p.nid }.join(', ')}"
          send_packet(:dht_burst_query, dest,
                      DHTBurstQuery.new(uid, src_addr, query, ttl - 1))
        end
      end
    end

    def us_or_dead?(uid, query, src_addr, ttl)
      if(query == @nid)
        log "#{@nid} - query: #{query} successful!"
        send_packet(:dht_response, src_addr, 
                    DHTResponse.new(uid, @addr, @nid, ttl))
        Analyzer::instance::successful_search_trial(uid)
        true
      elsif ttl == 0
        log "#{@nid} - query: #{query} ttl reached 0!"
        true
      else
        false
      end
    end

    def closer?(query, peer)
      @link_table.distance(query, peer.nid) < @link_table.distance(@nid, query)
    end

    def handle_dht_query(pkt)
      dht_query(pkt.uid, pkt.query, pkt.src_addr, pkt.ttl)
    end

    def handle_dht_burst_query(pkt)
      dht_burst_query(pkt.uid, pkt.query, pkt.src_addr, pkt.ttl)
    end

    # TODO: What do we want to do with search responses?
    def handle_dht_response(pkt)
      log "DHT got a query response..."
    end
  end
end
end

