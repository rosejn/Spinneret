#! /usr/bin/env ruby

if(ARGV.length < 1)
  puts "<dirs>"
  exit(0)
end

reg_ex = ARGV[0].gsub(/\*/, "(.+)")

dirs = Dir.glob(ARGV[0])
points = []
dirs.each do | dir | 
  next if !File.directory?(dir)

  filename = File.join(dir, "search_success_pct")
  next if !File.exist?(filename)

  puts filename

  rows = File.open(filename).readlines()

  dht_pct = File.open(File.join(dir, "search_success_pct_dht"), "w+")
  kwalk_pct = File.open(File.join(dir, "search_success_pct_kwalker"), "w+")

  tot = 0.0
  rows.each do | row |
    vals = row.split.map { | val | val.to_i }
    dht_trials = (vals[1] + vals[2]).to_f
    kwalk_trials = (vals[3] + vals[4]).to_f
    dht_pct.write "#{vals[0]} #{vals[1]/dht_trials}\n"
    kwalk_pct.write "#{vals[0]} #{vals[3]/kwalk_trials}\n"
  end
end
