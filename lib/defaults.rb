module Spinneret
    def Spinneret.set_defaults
      c = Configuration::instance

      # Node
      n = c.node = OpenStruct.new
      #n.maintenance_algorithm = Maintenance::Pull
      #n.maintenance_algorithm = Maintenance::Push
      n.maintenance_algorithm = Maintenance::PushPull
      n.maintenance_size = 5
      n.maintenance_rate = 1000

      # Link Table
      lt = c.link_table = OpenStruct.new
      lt.max_peers = 15
      lt.address_space = 10000

      # Analyzer
      an = c.analyzer = OpenStruct.new
      an.measurement_period = 10000
      an.output_path = 'output'
    end

  set_defaults
end
