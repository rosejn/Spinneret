module Spinneret
module Search

  JOIN_TTL = 20

  module JoinQuery
    def run_join_query(id, peers, idx, ttl = JOIN_TTL)
#     GoSim::Data::DataSet[:dht_search].log(:new, @uid, dest_addr, nil, @nid)
      if(ttl > 0)
        d = peers[idx].join_query(id)

        d.add_callback do | new_peers |
          new_peers.each { | p | @link_table.store_peer(p.addr) }
          if(new_peers.empty?)
            run_join_query(id, peers, idx + 1, ttl)  if peers.length > idx + 1
          elsif(closer_than?(id, new_peers[0], peers[idx]))
          #    puts "#{@nid}: #{new_peers[0].nid} ~ #{peers[idx].nid}"
            run_join_query(id, new_peers, 0, ttl - 1)
          else
            peers[idx].table_pull().add_callback do | tbl | 
              tbl.each { | n | @link_table.store_peer(n) }
            end
          end
        end

        d.add_errback do | x |
          run_join_query(id, peers, idx + 1, ttl)  if peers.length > idx + 1
        end

      end
    end

    # Do a logarithmic query where at each hop we jump to the closest node
    # possible in the current link table.
    def join_query(query)
      log { "node: #{@nid} - join_query( q = #{query})" }

      @link_table.closest_peers(query, 3)
    end

    def table_pull
      return @link_table.peers.map { | p | p.addr }
    end

    def closer_than?(q, peer1, peer2)
      @link_table.distance(q, peer1.nid) < @link_table.distance(q, peer2.nid)
    end

  end
end
end

