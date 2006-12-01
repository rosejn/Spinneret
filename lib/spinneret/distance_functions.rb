module DistanceFuncs
  # The absolute distance on a modular single dimensional number line.
  def DistanceFuncs.sym_circular(addr_size)
    return Proc.new do | x, y |
      d1 = (y - x).abs
      min = (y < x ? y : x)
      max = (y >= x ? y : x)
      d2 = (addr_size - max) + min

      (d1 < d2 ? d1 : d2)
    end
  end
end
