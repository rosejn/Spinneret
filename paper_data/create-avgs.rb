#! /usr/bin/env ruby

# == Synopsis
#
# create-avgs.rb: create averages from the tails of trace files, printing them
# to stdout.
#
# == Usage
#
# create-avgs.rb [OPTIONS]
#
# -h, --help
#    Show this help
#
# -d directory_wildcard, --directories directory_wildcard
#    Give the wildcard for the directories to be scanned for the given filename
#    (see below).  Note that the '*' must be escaped, else the shell will match
#    it.  Eg
#      -d dirs_\*
#    would match dirs_1, dirs_2, etc, while
#      -d dirs_*
#    would only read the first match directory.
#
# -f filename, --filename filename
#    Gives the name of the file to average.
#
                # -n rows, --number-of-rows rows
#    Gives the number of rows which should be averaged.  The last row of data
#    files is always ignored as invalid
#
# -c column, --column column
#    Gives the column of the data which is being averaged.  Index starts at 0.
#

require 'rdoc/usage'
require 'getoptlong'

require 'rubygems'
require 'gsl'

opts = GetoptLong.new(
        ['--help',                   '-h', GetoptLong::NO_ARGUMENT],
        ['--directories',            '-d', GetoptLong::REQUIRED_ARGUMENT],
        ['--filename',               '-f', GetoptLong::REQUIRED_ARGUMENT],
        ['--number-of-rows',         '-n', GetoptLong::REQUIRED_ARGUMENT],
        ['--column',                 '-c', GetoptLong::REQUIRED_ARGUMENT])


num_rows = col = reg_ex = dirs = file = nil
opts.each do | opt, arg |
  case opt
  when '--help'
    RDoc::usage
    exit(0)
  when '--directories'
    reg_ex = arg.gsub(/\*/, "(.+)")
    dirs = Dir.glob(arg)
  when '--filename'
    file = arg
  when '--number-of-rows'
    num_rows = arg.to_i
  when '--column'
    col = arg.to_i
  end
end

if(reg_ex.nil? || dirs.length < 1 || file.nil? || num_rows.nil? || col.nil?)
  RDoc::usage
  exit(-1)
end

points = []
dirs.each do | dir | 
  next if !File.directory?(dir)

  filename = File.join(dir, file)
  next if !File.exist?(filename)

  rows = File.open(filename).readlines()
  next if rows.length < num_rows + 1

  tot = []
  rows[-(num_rows + 1), num_rows].each do | row |
    vals = row.split
    break if vals.length < col
    tot << vals[col].to_f
  end

  pos = Regexp.new(reg_ex).match(dir)[1]
  v = GSL::Vector.alloc(tot)
  points << [pos, GSL::Stats::mean(v), GSL::Stats::sd(v)]
end

points.sort! { | x, y | x[0].to_i <=> y[0].to_i }
points.each { | p | puts "#{p[0]} #{p[1]} #{p[2]}" } 
