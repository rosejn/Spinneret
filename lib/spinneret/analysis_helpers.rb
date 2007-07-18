require 'math_ext'

require 'rgl/base'
require 'rgl/adjacency'
require 'rgl/traversal'
require 'rgl/implicit'

include RGL

module Graph 
  def avg_path_length(n = 10)
    verts = vertices()

    path_length = 0.0
    n.times do
      v2 = v1 = verts.rand()
      v2 = verts.rand() while v2 == v1

      iter = bfs_iterator(v1)
      iter.attach_distance_map()
      iter.set_to_end   # do search, mark distances

      length = iter.distance_to_root(v2)
#      puts "#{v1} -> #{v2} => #{length}"
      path_length += length
    end

    return path_length /= n.to_f
  end

  def directed_cluster_coeff(v)
    num_edges = 0
    neighbors = Set.new
    each_adjacent(v) do | k |
      num_edges += 1
      neighbors.add(k)
    end

    return 0 if num_edges <= 1

    puts "N: #{neighbors.to_a.sort.join(', ')}"

    nofns = Set.new
    neighbors.each do | k |
      puts "#{k}"
      each_adjacent(k) do | kk |
        puts "  #{kk}"
        # note that [kk, k] is considered a different edge
        if(neighbors.member?(kk) && (directed? || !nofns.member?([kk, k])))
           nofns.add([k, kk]) if neighbors.member?(kk)
        end
      end
    end

    return ((directed? ? 1.0 : 2.0) * nofns.size()) / (num_edges * (num_edges - 1))
  end
end
