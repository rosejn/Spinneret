#!/usr/bin/env ruby

FILEMASK = /(\d+)(\D[\w\._\-]+)/

outfile = File.open(ARGV[1], "w")
i = 1
files = Dir.glob(ARGV[0]).sort do | x, y |
  FILEMASK.match(File.basename(x))[1].to_i <=> FILEMASK.match(File.basename(y))[1].to_i
end 

files.each do | file |
  File.open(file) do | disc |
    s = "#{i*10000} " + disc.readline()
    outfile << s
    i += 1
  end
end
outfile.close()
