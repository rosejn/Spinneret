def Math.log_n(x, n)
  return Math.log(x) / Math.log(n)
end

class Array
  def grab_n(n)
    if n >= self.length 
      return self.clone
    end

    i = 0
    arr = []
    while i < n
      k = self[rand(self.length)]
      next if arr.include?(k)
      arr << k
      i += 1
    end

    return arr
  end
end

def test_src_ndest(ary, num_tests, ndest, &block)
  sources = ary.grab_n(num_tests)
  destinations = sources.map do |s| 
    dests = []
    ndest.times do 
      while(s == (d = ary[rand(ary.length)])); end
      dests << d
    end
    dests
  end

  sources.each_with_index {|s, i| block.call(s, destinations[i]) }
end
