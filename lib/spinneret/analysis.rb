module Spinneret

  class Analyzer < GoSim::Entity
    def initialize nodes, output_path
      super()
      @nodes = nodes
      @output_path = output_path
    end

    def handle_link_count
      links = {}

      @nodes.each do |n| 
        l = n.size
        links.has_key?(l) ? links[l] += 1 : links[l] = 1
      end

      File.open(File.join(output_path, @sim.time, '_link_count')) do |f|
        links.each {|k,v| f << "#{k} #{v}" }
      end
    end

    def handle_bin_count
      bins = {}

      @nodes.each do |n|

      end
    end
  end

end
