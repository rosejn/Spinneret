module Spinneret

  MAX_COST = 2**31

  class IdealizedLinkTable
    def initialize(nid, real_tbl)
      @nid = nid
      @real_tbl = real_tbl
      @ideal_slope = Math::log2(@real_tbl.address_space) / @real_tbl.max_peers
      @idealized_tbl = Array.new(@real_tbl.max_peers, 0)

      distribute_table()
    end

    def distance(x, y)
      @real_tbl.distance(x, y)
    end

    def index_distance(idx)
      idx * @ideal_slope
    end

    def distribute_table
      @real_tbl.peers_by_distance.each do | p |
        ideal_idx = (p.distance / @ideal_slope).round
        if(ideal_idx == 0)
          @idealized_tbl[ideal_idx] = p.distance
        else
          left_cost = move_cost(ideal_idx, -1)
          right_cost = move_cost(ideal_idx, 1)
          if(left_cost < right_cost)
            #move_left(ideal_idx)
          elsif(right_cost < left_cost)
            #move_right(ideal_idx)
          else
            move = rand()
            #move_left(ideal_idx)  if move < 0.5
            #move_right(ideal_idx) if move >= 0.5
          end
        end
      end
    end

    def each_with_index

    end

    def move_cost(ideal_idx, dir)
      cost = 0
      while(ideal_idx >= 0 &&
            ideal_idx != @real_tbl.max_peers - 1 &&
            @idealized_tbl[ideal_idx] != 0)

        cost += (index_distance(ideal_idx + dir) - @idealized_tbl[ideal_idx]).abs
        ideal_idx += dir
      end

      return cost       if @idealized_tbl[ideal_idx] == 0
      return MAX_COST   #else
    end

  end
end

