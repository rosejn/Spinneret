module LTAlgorithms
  module Base
    MAX_DIST = 2 ** 160

    def find_smallest_dist(dist_array)
      return nil  if dist_array.length < 2

      sorted_peers = peers_by_distance(dist_array)

      i_min = 1
      v_min = MAX_DIST

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
      smallest = find_smallest_dist(@nid_peers.values)

#      puts "Removing #{smallest.inspect}."

      GoSim::Data::DataSet[:link].log(:remove, @nid, smallest)
      @nid_peers.delete(smallest) { | key | raise "#{key} removed val not found." }

#      puts "#{@nid}: Table size is now #{@nid_peers.length}."
    end

  end # LinkTable
end # Spinneret
