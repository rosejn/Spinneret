#!/usr/bin/env ruby

require 'zlib'

def density(id)
  sizes = []
  sizes << $bucket_size / 100
  #sizes << 100000000
  48.times { | t | sizes << sizes[t] / 2 }

  puts "Sample size,  density"
  sizes.each do | size |
    puts "#{size}: #{density_size(id, size)}"
  end
end

def density_size(id, size)
  idx = $ids.index(id)

  left_side = id - (size / 2)
  right_side = id + (size / 2)

  num_nodes = 0

  search_idx = idx - 1
  while(search_idx >= 0 && $ids[search_idx] >= left_side)
    num_nodes += 1
    search_idx -= 1
  end

  search_idx = idx + 1
  length = $ids.length
  while(search_idx < length && $ids[search_idx] <= right_side)
    num_nodes += 1
    search_idx += 1
  end

  puts "#{size}: #{num_nodes}"

  num_nodes / size.to_f
end

if(ARGV.length < 3)
  puts "Usage: id-density <filename> <max_id> <num_buckets>"
  exit(0)
end

file = ARGV[0]

max_id = ARGV[1].to_i
num_buckets = ARGV[2].to_i
$bucket_size = max_id / num_buckets

buckets = Array.new(num_buckets, 0)
$ids = []
Zlib::GzipReader.open(file) do | f |
  begin
    while(true)
      s = f.readline()
      if s =~ /(\d+) (init)(.*)/
        $ids << $1.to_i
        buckets[$1.to_i / $bucket_size] += 1
      end
    end
  rescue
    printf("Read done.\n")
  end
end

$ids.sort!

puts $ids

=begin
avg_density = $ids.length / max_id.to_f
puts "Avg. Density: #{avg_density}"

command = ""
while(command != "quit" && command != "q")
  command = STDIN.readline().strip()
  density(command.to_i) if command =~ /\d+/
end
=end
