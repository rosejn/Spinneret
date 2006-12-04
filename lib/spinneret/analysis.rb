module Spinneret

  class Analyzer < GoSim::Entity
    include Base

    def initialize nodes, output_path
      super()
      @nodes = nodes
      @output_path = output_path  
      @output_path += "/"  if @output_path[-1].to_chr != "/"
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

    def handle_indegree_calc
      nodes_in = Hash.new(0)
      @nodes.each do | n |
        n.link_table.each { | out_e | node_in[out_e] += 1 }
      end

      dist = Array.new(0, 0)
      nodes_in.each { | node, in_e | dist[in_e] += 1 }
      File.open(outout_path + @sim.time.to_s + "_indegree_dist"
    end

  end
end
