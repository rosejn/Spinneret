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
      @output_path += "/"  if @output_path[-1].chr != "/"

      @high_indegree = Hash.new(0)

      set_timeout(100, true) { indegree_calc }
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

    def indegree_calc
      nodes_in = Hash.new(0)
      @nodes.each do | n|
        n.link_table.each { | out_e | nodes_in[out_e.nid] += 1 }
      end

      max = nodes_in.values.max
      return  if max.nil?
  
      File.open(@output_path + @sim.time.to_s + "_indegree_node", "w") do | f |
        sorted = nodes_in.sort { | p1, p2 | p1[1] <=> p2[1] }
        sorted.each { | x | f.write("#{x[0]} #{x[1]}\n") }
        if sorted.length > 10
          sorted[-5..-1].each { | x | @high_indegree[x[0]] += 1 }
        end
      end

      File.open(@output_path + @sim.time.to_s + "_high_indegree", "w") do | f |
        @high_indegree.each { | node, times | f.write("#{node} #{times}\n") }
      end

      distrib = Array.new(max + 1, 0)
      nodes_in.each { | node, in_e | distrib[in_e] += 1 }
      distrib.map! { | x | (x.nil? ? 0 : x) }
      File.open(@output_path + @sim.time.to_s + "_indegree_dist", "w") do | f |
        distrib.each_index { | idx | f.write("#{idx} #{distrib[idx]}\n") }
      end

      normal_dist = normal_fit(distrib)
      puts normal_dist
    end

    def normal_fit(data)
      mean = 0
      length = 0.0
      variance = 0
      data.each { | x | if x != 0; mean += x; length += 1; end }
      mean /= Float(data.length)
      data.each { | x | variance += (x - mean) ** 2 }
      variance /= Float(data.length)
      std_dev = Math::sqrt(variance)

      return [mean, std_dev]
    end
  end

end
