module Spinneret
module Search
  DHTQuery = Struct.new(:src_addr, :query, :ttl)
  DHTBurstQuery = Struct.new(:src_addr, :query, :ttl)
  DHTResponse = Struct.new(:src_addr, :src_id, :ttl)

  DHT_TTL          = 20
  DHT_BURST_TTL    = 4
  DHT_BURST_SIZE   = 4
  DHT_BURST_CHANCE = 0.5

  module DHT
    # Do a logarithmic query where at each hop we jump to the closest node
    # possible in the current link table.
    def dht_query(query, src_addr = @addr, ttl = DHT_TTL)
      #log "node: #{@nid} - dht_query( q = #{query})"

      unless us_or_dead?(query, src_addr, ttl)
        # Find closest neighbor and figure out whether we burst or jump.
        closest = @link_table.closest_peer(query)

        return if closest.nil? # Can't do anything if we don't have peers...

        if closer?(query, closest) # Jump
          dest = closest.addr
          #log "dht query: #{query} to dest: #{closest.nid}"
          send_packet(:dht_query, dest, 
                      DHTQuery.new(src_addr, query, ttl))
         
        # Start the burst query
        else 
          dht_burst_query(query, src_addr, DHT_BURST_TTL)
        end
      end
    end

    # Do a localized, probabalistic burst flood to get over local minima close
    # to the query target.
    def dht_burst_query(query, src_addr, ttl)
      log "node: #{@nid} - dht_query( q = #{query})"

      unless us_or_dead?(query, src_addr, ttl)
        peers = @link_table.closest_nodes(query, DHT_BURST_SIZE)

        # If one of our immediate neighbors is the target go straight there.
        if peers.first.nid == query
          dest = peers.first.addr
          
        # Otherwise we follow the burst chance
        else
          dest = peers.select { rand <= DHT_BURST_CHANCE }.map {|p| p.addr }
        end

        log "dht burst query: #{query} to dest: #{peers.map {|p| p.nid }}"
        send_packet(:dht_burst_query, dest,
                    DHTBurstQuery(src_addr, query, ttl - 1))
      end
    end

    def us_or_dead?(query, src_addr, ttl)
      if(query == @nid)
        send_packet(:dht_response, src_addr, 
                    DHTResponse.new(@addr, @nid, ttl))
        true
      elsif ttl == 0
        true
      else
        false
      end
    end

    def closer?(query, peer)
      @link_table.distance(query, peer.nid) < @link_table.distance(@nid, query)
    end

    def handle_dht_query(pkt)
      dht_query(pkt.query, pkt.src_addr, pkt.ttl)
    end

    def handle_dht_burst(pkt)
      dht_burst_query(pkt.query, pkt.src_addr, pkt.ttl)
    end

    # TODO: What do we want to do with search responses?
    def handle_dht_response(pkt)
      log "DHT got a query response..."
    end
  end
end
end

