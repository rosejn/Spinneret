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
    def dht_query(query, src_addr = @addr, ttl = DHT_TTL)
      #log "node: #{@nid} - dht_query( q = #{query})"

      if(query == @nid)
        send_packet(:dht_response, src_addr, 
                    DHTResponse.new(@addr, @nid, ttl))
      elsif ttl == 0
        return

      else 
        
        # Find closest neighbor and figure out whether we burst or jump.
        closest = @link_table.closest_peer(query)

        return if closest.nil? # Can't do anything if we don't have peers...

        if closer?(query, closest) # Jump
          dest = closest.addr
          #log "dht query: #{query} to dest: #{closest.nid}"
          send_packet(:dht_query, dest, 
                      DHTQuery.new(src_addr, query, ttl))

        else # Start the burst query
          dht_burst_query(query, src_addr, DHT_BURST_TTL)
        end
      end
    end

    def dht_burst_query(query, src_addr, ttl)
      log "node: #{@nid} - dht_query( q = #{query})"

      if(query == @nid)
        send_packet(:dht_response, src_addr, 
                    DHTResponse.new(@addr, @nid, ttl))
      elsif ttl == 0
        return

      else
        peers = @link_table.closest_nodes(query, DHT_BURST_SIZE).
          select { rand <= DHT_BURST_CHANCE }

        dest = peers.map {|p| p.addr }

        log "dht burst query: #{query} to dest: #{peers.map {|p| p.nid }}"
        send_packet(:dht_burst_query, dest,
                    DHTBurstQuery(src_addr, query, ttl - 1))
      end
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

    def closer?(query, peer)
      @link_table.distance(query, peer.nid) < @link_table.distance(@nid, query)
    end
  end
end
end

