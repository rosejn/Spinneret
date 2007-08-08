#! /usr/bin/env ruby


if(ARGV.length < 3)
  puts "<dirs> <filename> <num rows> <col>"
  exit(0)
end

num_rows = ARGV[2].to_i
col = ARGV[3].to_i
reg_ex = ARGV[0].gsub(/\*/, "(.+)")

dirs = Dir.glob(ARGV[0])
points = []
dirs.each do | dir | 
  next if !File.directory?(dir)

  filename = File.join(dir, ARGV[1])
  next if !File.exist?(filename)

  rows = File.open(filename).readlines()
  next if rows.length < num_rows + 1

  tot = 0.0
  rows[-(num_rows + 1), num_rows].each do | row |
    vals = row.split
    break if vals.length < col
    tot += vals[col].to_f
  end

  avg = tot / num_rows;

  pos = Regexp.new(reg_ex).match(dir)[1]
  points << [pos, avg]
end

points.sort! { | x, y | x[0].to_i <=> y[0].to_i }
points.each { | p | puts "#{p[0]} #{p[1]}" } 
