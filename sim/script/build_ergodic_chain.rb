#!/usr/bin/env ruby

require 'rubygems'
require 'zlib'
require 'gsl'

require 'spinneret'

class PathTransitionMatrix

  def initialize(stream)
    @graph = RGL::DirectedAdjacencyGraph.new().read_from_dot(stream)
    @matrix = GSL::Matrix.alloc(@graph.num_vertices, @graph.num_vertices)

    @cur_name = 0
    @vertex_names = {}

    generate_matrix()
  end

  def write_node_probs(stream)
    return unless @converged

    @vertex_names.each do | key, value |
      stream.write("#{key} #{@converged.col(value)[0]} #{@converged.col(value)[100]}\n")
    end
  end

  def converge
    res = @matrix ^ 2
    @converged = res * @matrix

    i = 0
    while !res.equal?(@converged)
      res = @converged
      @converged = @converged * @matrix

      i += 1
      if(i % 10 == 9)
        puts "#{i+1} steps have passed (sqme #{(@converged - res).norm})"
      end
    end

    puts "#{i+1} steps have passed - converged"
  end

  private

  def get_name(v)
    if !@vertex_names.has_key? v
      @vertex_names[v] = @cur_name  
      @cur_name += 1
    end

    return @vertex_names[v]
  end

  def generate_matrix
    puts "Generating..."
    @graph.each_vertex do | v |
      @graph.each_adjacent(v) do | u |
      @matrix.set(get_name(v), get_name(u), 1)
      end
    end

    puts "Normalizing..."
    @matrix.each_row do | row |
      size = row.sum
      row.collect! { | val | val / size }
    end

    puts "Checking..."
    @matrix.each_row { | row | puts "error" unless row.sum == 1.0 }
    puts "Done."
  end

end

if(ARGV.length < 2)
  puts "Please provide filename and output name."
  exit
end

p = PathTransitionMatrix.new(Zlib::GzipReader::open(ARGV[0]))
puts "Running convergence..."
p.converge
p.write_node_probs(File.open(ARGV[1], "w"))
puts "Done."
