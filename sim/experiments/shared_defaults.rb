$defaults = {
#  'node.maintenance_algorithm' => Maintenance::PushPull,
  'node.maintenance_opportunistic_alwayson' => true,
  'node.maintenance_size' => 10,
  'node.maintenance_rate' => 1000,

  # Link Table
  'link_table.max_peers' => 15,
  'link_table.address_space' => 2**160,

  # Analyzer
  'analyzer.measurement_period' => 10000,
  'analyzer.output_path' => 'output'
}

