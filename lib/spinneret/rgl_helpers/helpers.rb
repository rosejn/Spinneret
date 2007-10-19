require 'rgl/base'
require 'rgl/adjacency'
require 'rgl/traversal'
require 'rgl/implicit'
require 'rgl/connected_components'

include RGL

# This should really be type (digraph/unigraph) agnostic, but ehh, whatever 
# for now.
class DirectedAdjacencyGraph
  EDGE_RE = /^\s*(\d+)->(\d+)[^;]*;/
  NODE_RE = /^\s*(\d+) ?([^;]*);/

  NODE_INFO_RE = /(\w+)="(\d+\.?\d*)"/

  def read_from_dot(stream)
    stream.each_line() do | line |
      case line
      when EDGE_RE
        add_edge($1.to_i, $2.to_i)
      when NODE_RE
        v = $1.to_i
        add_vertex(v)

        remainder = $2
        while(!remainder.nil?)
          if remainder =~ NODE_INFO_RE
            remainder = $' 
            name = $1
            val = $2
            case val
            when /^\d+\.\d+$/
              val = val.to_f
            when /^\d+$/
              val = val.to_i
            end
            add_vertex_property(v, name, val)
          else
            break
          end
        end
      else
        # eat the line for now
        # puts "Unknown line:\n #{line}"
      end
    end # each_line

    self
  end

end

module Graph 
  def add_vertex_property(vertex, name, property)
    @vertex_properties ||= {}
    @vertex_properties[vertex] ||= {}
    @vertex_properties[vertex][name.to_sym] = property
    #puts "Added 0x#{vertex.to_s[0..5]}...[#{name}] = #{property}."
  end

  def get_vertex_property(vertex, name)
    @vertex_properties ||= {}
    if @vertex_properties.has_key?(vertex)
      if @vertex_properties[vertex].has_key?(name.to_sym)
        return @vertex_properties[vertex][name.to_sym]
      end
    end

    return nil
  end

  # All of this is no longer used.  Depreicated, delete latter.
=begin
  def avg_path_length(n = 1000)
    verts = vertices()

    path_length = 0.0
    n.times do
      v2 = v1 = verts.rand()
      v2 = verts.rand() while v2 == v1

      iter = bfs_iterator(v1)
      iter.attach_distance_map()
      iter.set_to_end()   # do search, mark distances

      length = iter.distance_to_root(v2)
#      puts "#{v1} -> #{v2} => #{length}"
      path_length += length
    end

    return path_length /= n.to_f
  end

  def cluster_coeff()
    v = vertices()
    v.inject(0) { | val, idx | val += node_cluster_coeff(idx) } / v.size.to_f
  end

  def node_cluster_coeff(v)
    num_edges = 0
    neighbors = Set.new
    each_adjacent(v) do | k |
      num_edges += 1
      neighbors.add(k)
    end

    return 0 if num_edges <= 1

#    puts "N: #{neighbors.to_a.sort.join(', ')}"

    nofns = Set.new
    neighbors.each do | k |
#      puts "#{k}"
      each_adjacent(k) do | kk |
#        puts "  #{kk}"
        # note that [kk, k] is considered a different edge
        if(neighbors.member?(kk) && (directed? || !nofns.member?([kk, k])))
           nofns.add([k, kk]) if neighbors.member?(kk)
        end
      end
    end

    return ((directed? ? 1.0 : 2.0) * nofns.size()) / 
              (num_edges * (num_edges - 1)).to_f
  end
=end

  #[id=\"#{k.nid}\", visit_freq=\"#{k.visit_avg.avg}\"];\n"
  def vertex_props_dot(v)
    @vertex_properties ||= {}
    s = ""
    if @vertex_properties.has_key?(v)
      if @vertex_properties[v].size > 0
        s << " [" 
        s << @vertex_properties[v].map do | name, value |
          if value.class == Float
            value = sprintf("%9.9f", value)
          end
          name.to_s + "=\"#{value}\""
        end.join(", ")
        s << "]"
      end
    end
    s << ";\n"

    return s
  end

  def to_dot(graph_attrs = {})
    v = vertices()
    s = "digraph G {\n"
    graph_attrs.each {|name, val| s << "#{name}=\"#{val}\";\n"}
    v.each do | k |
      s << "#{k.to_d}" << vertex_props_dot(k) << dot_node(k)
    end
    s << "}\n"
  end

  def dot_node(k)
    s = ""
    each_adjacent(k) { | kk | s << "#{k.to_d}->#{kk.to_d};\n" if !kk.nil? } 
    return s
  end
end
