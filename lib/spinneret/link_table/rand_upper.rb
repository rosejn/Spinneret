module LTAlgorithms
  module RandUpper

    include LTAlgorithms::Base

    def find_smallest_dist(dist_array)
      # Distance on either side in which to consider nodes
      quarter_space = Math.log2(@config.address_space / @config.address_space_divider)

      sorted_peers = peers_by_distance()

      i = 0
      while i < sorted_peers.length && sorted_peers[i].distance < quarter_space
        i += 1  
      end

      # sort peers based on how they should be considered
      below_peers = sorted_peers[0..i-1]
      above_peers = sorted_peers[i..-1]
    
      # Do we need to cut above or below?
      if above_peers.length >= below_peers.length  # cut above
        peer = above_peers.rand
      else
        peer = super(below_peers)
      end

      return peer
    end

  end # RandUpper
end # LTAlgorithms
