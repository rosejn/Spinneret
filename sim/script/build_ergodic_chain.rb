#!/usr/bin/env ruby

# == Synopsis
#
# build_ergodic_chain: Analize graph reachability properties
#
# == Usage
#
# -h, --help:
#    Show this help.
#
# -o filename, --output filename
#
# -i filename, --input filename
#
# -e, --ergodic
#
# -r length, --random-walk length 
#    Optional argument

require 'rdoc/usage'
require 'getoptlong'
require 'zlib'

require 'rubygems'
require 'gsl'

require 'spinneret'

#require 'profile'

class PathTransitionMatrix

  def initialize(stream)
    @graph = RGL::DirectedAdjacencyGraph.new().read_from_dot(stream)
    @matrix = GSL::Matrix.alloc(@graph.num_vertices, @graph.num_vertices)

    @cur_name = 0
    @vertex_names = {}
    @args = {}
  end

  def set_args(hash)
    @args.merge!(hash)
  end

  private

  def get_name(v)
    if !@vertex_names.has_key? v
      @vertex_names[v] = @cur_name  
      @cur_name += 1
    end

    return @vertex_names[v]
  end

end

class GraphRandomWalk < PathTransitionMatrix
  DEFAULT_WALK_LENGTH = 40

  def initialize(stream, length = DEFAULT_WALK_LENGTH)
    super(stream)
    @converged = false
    @vert_edges = {}
    @args[:length] = length
  end

  def converge
    verts = @graph.vertices
    
    prev_probs = GSL::Matrix.alloc(@graph.num_vertices, @graph.num_vertices)
    i = 0
    while(!@converged)
      verts.each do | v |
        #puts "0x#{v.to_s[0..10]}..."
        verts.size.times do
          u = v
          @args[:length].times { u = vertices(u).rand() }

          v_name, u_name = get_name(v), get_name(u)
          @matrix.set(v_name, u_name, @matrix.get(v_name, u_name) + 1)
        end
      end

      @probs = normalize(@matrix, (i + 1) * verts.size)
      @converged = @probs.equal?(prev_probs)

      if(i % 10 == 4)
        puts "#{i+1} steps have passed (sqme #{(@probs - prev_probs).norm})"
        f = File.new("#{i+1}.probs", "w")
        write_node_probs(f)
        f.close() # force flush in case of early exit
      end
      i += 1

      prev_probs = @probs
    end  # !converged

  end

  def write_node_probs(stream)
#    return unless @converged
  
    @vertex_names.each do | key, value |
      # Note, all rows should be created equal, but maybe we should average
      # here instead of just picking the first one
      col = @probs.col(value)
      stream.write("#{key} #{col[0]} #{col.sum / col.size}\n")
    end
  end

  private

  def vertices(v)
    if !@vert_edges.has_key?(v)
      @vert_edges[v] = @graph.adjacent_vertices(v)
    end

    return @vert_edges[v]
  end

  def normalize(matrix, trials)
    new_matrix = GSL::Matrix.alloc(@graph.num_vertices, @graph.num_vertices)

    matrix.size1.times do | i | 
      row = matrix.get_row(i)
      sum = row.sum
      row.collect! { | val | val / sum }
      new_matrix.set_row(i, row)
    end

    return new_matrix
  end

end

class ErgodicTransitionMatrix < PathTransitionMatrix

  def initialize(stream)
    super(stream)

    @converged = nil
    generate_matrix()
  end

  def write_node_probs(stream)
    return unless @converged

    @vertex_names.each do | key, value |
      # Note, all rows should be created equal, but maybe we should average
      # here instead of just picking the first one
      stream.write("#{key} #{@converged.col(value)[0]}\n")
    end
  end

  def converge
    res = @matrix ^ 2
    @converged = res * @matrix

    i = 0
    while !res.equal?(@converged)
      res = @converged
      @converged = @converged * @matrix

      if(i % 10 == 9)
        puts "#{i+1} steps have passed (sqme #{(@converged - res).norm})"
      end
      i += 1
    end

    puts "#{i+1} steps have passed - converged"
  end

  private

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

opts = GetoptLong.new(
        ['--help',                   '-h', GetoptLong::NO_ARGUMENT],
        ['--output',                 '-o', GetoptLong::REQUIRED_ARGUMENT],
        ['--input',                  '-i', GetoptLong::REQUIRED_ARGUMENT],
        ['--ergodic',                '-e', GetoptLong::NO_ARGUMENT],
        ['--random-walk',            '-r', GetoptLong::OPTIONAL_ARGUMENT])

output_filename = nil
input_filename = nil
convergence_class = nil
args = {}
opts.each do | opt, arg |
  case opt
  when '--help'
    RDoc::usage
    exit(0)
  when '--output'
    output_filename = arg
  when '--input'
    input_filename = arg
  when '--ergodic'
    convergence_class = ErgodicTransitionMatrix
  when '--random-walk'
    convergence_class = GraphRandomWalk
    args[:length] = arg.to_i unless arg.nil
  end
end

if(output_filename.nil? || input_filename.nil? || convergence_class.nil?)
  RDoc::usage
  exit(-1)
end

p = convergence_class.new(Zlib::GzipReader::open(input_filename))
p.set_args(args)
puts "Running convergence..."
p.converge
p.write_node_probs(File.open(output_filename, "w"))
puts "Done."
