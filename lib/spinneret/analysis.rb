module Spinneret

  class Analyzer < GoSim::Entity
    include Base
    include KeywordProcessor

    DEFAULT_STABILITY_THRESHOLD = 10
    DEFAULT_OUTPUT_PATH = 'output'

    attr_reader :graph

    def initialize(nodes, args = {})
      super()

      params_to_ivars(args, {
                     :output_path => DEFAULT_OUTPUT_PATH,
                     :stability_threshold => DEFAULT_STABILITY_THRESHOLD,
                     :stability_handler => method(:default_stable_handler) 
      })

      @nodes = nodes

      @high_indegree = Hash.new(0)

      #set_timeout(100, true) { indegree_calc }

      setup_rgl_graph
      set_timeout(100, true) { is_connected? }
    end

    def setup_rgl_graph
      require 'rgl/base'
      require 'rgl/implicit'
      require 'rgl/connected_components'

      @node_hash = {}

      @graph = RGL::ImplicitGraph.new do |g|
          g.vertex_iterator { |block|
            @nodes.each {|n| block.call(n) }
          }

          g.adjacent_iterator { |node, block|
            node.link_table.peers.each do |peer|
              block.call(@node_hash[peer.nid])
            end
          }

          g.directed = true
      end
    end

    def is_connected?
      connected_components == 1
    end

    def connected_components
      @nodes.each {|n| @node_hash[n.nid] = n }
      @graph.strongly_connected_components.num_comp
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
  
      File.open(File.join(@output_path, @sim.time.to_s + "_indegree_node"), "w") do | f |
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

      name = @sim.time.to_s + "_indegree_dist"
      File.open(File.join(@output_path, name), "w") do | f |
        distrib.each_index { | idx | f.write("#{idx} #{distrib[idx]}\n") }
      end

      pts = []
      distrib.each_index { | idx | distrib[idx].times { pts << idx } }
      normal_dist = normal_fit(pts)
      puts normal_dist

      # Make a link to the current one for live graphing...
      cur_path = File.join(@output_path, "cur_indegree_dist")
      File.delete(cur_path) if File.symlink?(cur_path)
      File.symlink(name, cur_path)
    end

    def normal_fit(data)
      p data
      v = GSL::Vector.alloc(data)
      return [GSL::Stats::mean(v), GSL::Stats::sd(v)]
    end
  end

end
