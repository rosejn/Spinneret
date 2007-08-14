#!/usr/bin/env ruby

require 'rubygems'
require 'zlib'
require 'gsl'

require 'spinneret'

graph = RGL::DirectedAdjacencyGraph.new()
graph.read_from_dot(Zlib::GzipReader::open(ARGV[0]))

matrix = GSL::Matrix.alloc(graph.num_vertices, graph.num_vertices)

$cur_name = 0
$vertex_names = {}

def get_name(v)
  if !$vertex_names.has_key? v
    $vertex_names[v] = $cur_name  
    $cur_name += 1
  end

  return $vertex_names[v]
end

graph.each_vertex do | v |
  #puts v
  graph.each_adjacent(v) do | u |
    #puts "Setting [#{get_name(v)}, #{get_name(u)}] = 1."
    matrix.set(get_name(v), get_name(u), 1)
  end
end

puts "I've generated a #{matrix.size1}x#{matrix.size2} matrix."
