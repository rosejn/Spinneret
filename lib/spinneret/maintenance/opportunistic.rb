module Spinneret
module Maintenance
  module Opportunistic
    OpHeader = Struct.new(:neighbors, :args)

    def do_opportunistic(*args)
      c = Configuration::instance
      if(c.node.maintenance_opportunistic_alwayson || link_table.converged?)
        puts "oppor maintenance"
      end
    end
  end
end
end
