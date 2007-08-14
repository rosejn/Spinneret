module LTAlgorithms
  module RandUpper

    include LTAlgorithms::Base

    def find_smallest_dist(dist_array)
      # Distance on either side in which to consider nodes
      quarter_space = Math.log2(@config.address_space / @config.address_space_divider)

      sorted_peers = peers_by_distance(dist_array)

      i = 0
      while i < sorted_peers.length && sorted_peers[i].distance < quarter_space
        i += 1  
      end

      # sort peers based on how they should be considered
      below_peers = sorted_peers[0..i-1]
      above_peers = sorted_peers[i..-1]
    
      # Do we need to cut above or below?
      length_ratio = @config.address_space_divider / 2
      if above_peers.length > 
          @config.max_peers - (@config.max_peers / length_ratio)
        return above_peers.rand.nid
#        puts "cut above"
      else
        return super(below_peers)
#        puts "cut below"
      end
    end

  end # RandUpper
end # LTAlgorithms
