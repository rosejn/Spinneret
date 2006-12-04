module Spinneret

  class Analyzer < GoSim::Entity
    include Base
    include KeywordProcessor

    DEFAULT_STABILITY_THRESHOLD = 10

    def initialize(nodes, output_path, args = {})
      super()

      params_to_ivars(args, {
                     :stability_threshold => DEFAULT_STABILITY_THRESHOLD,
                     :stability_handler => method(:default_stable_handler) 
      })

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

    def handle_check_stability
      @nodes.detect(@stability_handler) do |n| 
        @stability_threshold > (@sim.time - n.link_table.last_modified)
      end
    end

    def default_stable_handler
      log "Network is stable..."
    end

    def handle_bin_distribution
      raise "Must specify an ideal_distribution to do the bin distribution analysis." unless @ideal_distribution 

      distances = {}

      @nodes.each do |n| 
        n.link_table.bin_sizes
        l = n.size
        links.has_key?(l) ? links[l] += 1 : links[l] = 1
      end

      File.open(File.join(output_path, @sim.time, '_link_count')) do |f|
        links.each {|k,v| f << "#{k} #{v}" }
      end

    end

    def chi_squared_distance(observed, expected)
      sum = 0
      observed.each_with_index do |o, i| 
        sum += (o - expected[i])**2 / expected[i]
      end
    end
  end

end
