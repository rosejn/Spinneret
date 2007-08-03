module LTAlgorithms
  module RandUpper

    include LTAlgorithms::Base

    def find_smallest_dist
      # Distance on either side in which to consider nodes
      quarter_space = Math.log2(@config.address_space / 4)

      sorted_peers = peers_by_distance()

      i = 0
      while sorted_peers[i].distance < quarter_space
        i += 1
      end

      below_peers = sorted_peers[0..i-1]
      above_peers = sorted_peers[i..-1]


    end

  end # RandUpper
end # LTAlgorithms
