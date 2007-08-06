module LTAlgorithms
  module Base

    def find_smallest_dist(dist_array)
      return nil  if dist_array.length < 2

      sorted_peers = peers_by_distance(dist_array)

      i_min = 1
      v_min = 2**160

      i = 1
      last_idx = sorted_peers.size - 1
      while(i != last_idx)
        a = sorted_peers[i-1]
        b = sorted_peers[i]
        c = sorted_peers[i+1]

        #dist = (b.distance - a.distance) + (c.distance - b.distance)
        dist = ((b.distance - a.distance) + (c.distance - b.distance))

        #dist = @cut_granularity if dist < @cut_granularity

        if(dist < v_min)
          i_min = i
          v_min = dist
        end
        i += 1
      end

      return sorted_peers[i_min].nid
    end

    # Trim based on only spacing
    # The nodes on the extreme ends always stay, and the node closest to its
    # two neighbors in the middle is booted.
    #
    # NOTE: This method is not threadsafe
    def trim
      smallest = find_smallest_dist(@nid_peers)

      GoSim::Data::DataSet[:link].log(:remove, @nid, smallest)
      @nid_peers.delete(smallest)
    end

  end # LinkTable
end # Spinneret
