#! /usr/bin/env ruby

require 'getoptlong'
require 'rdoc/usage'
require 'set'

opts = GetoptLong.new(
        ['--help',     '-h', GetoptLong::NO_ARGUMENT],
        ['--workload', '-w', GetoptLong::REQUIRED_ARGUMENT])

workload = nil
opts.each do | opt, arg |
  case opt
  when '--help'
    RDoc::usage
  when '--workload'
    workload = arg
  end
end

if workload.nil?
  puts "Must provide a workload with -w."
  exit(1)
end

class WLSet
  BASE_PATH = "data/bootstrap/workloads/"

  def initialize(wl)
    @wl = wl
    @wl_path = File.join(BASE_PATH, wl)
    @dir_struct = []

    gather_dir_structure(@wl_path, 0)
  end

  def gather_dir_structure(path, lvl)
    #puts "#{path} #{lvl}"

    sub_dirs = Dir.entries(path).select do | f | 
      if f == ".." || f == "."
        false
      else
        File.directory?(File.join(path, f))
      end
    end

    @dir_struct[lvl] ||= Set.new(sub_dirs)
    @dir_struct[lvl] &= sub_dirs
    @dir_struct[lvl].each do | dir |
      gather_dir_structure(File.join(path, dir), lvl + 1)
    end
  end

  HOPS_RE = /(\d+) (\d+(\.\d+)?)/
  def read_hops(filename)
    puts filename

    hops_total = []

    f = File.open(filename)
    f.each_line do | line |
      next if line !~ HOPS_RE

      time = $1.to_i
      hops = $2.to_f

      hops_total << hops  if(hops != 0)
    end

    # Sample the last 10, minus the very last one, which is biased high
    last_hops = hops_total[-11..-2].inject(0) { | ctr, n | ctr += n }
    return last_hops / 10
  end

  def graph_all
    plot_file = File.join("graph_data", @wl)
    data_file = @wl_path

    @dir_struct[2] = @dir_struct[2].sort { | x, y | x.to_i <=> y.to_i }

    @dir_struct[0].each do | f0 |
      @dir_struct[1].each do | f1 |
        @dir_struct[3].each do | f3 |
          cur_file = File.new("#{plot_file}_#{f0}_#{f1}_#{f3}", "w")
          @dir_struct[2].each do | f2 |
            hops = read_hops(File.join(@wl_path, f0, f1, f2, f3, "hop_average"))
            cur_file << "#{f2} #{hops}\n"
          end
        end
      end
    end

  end
end

wl_set = WLSet.new(File.basename(workload))
wl_set.graph_all
