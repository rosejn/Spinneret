# Load the hash names into the hierarchical config structure.  See the spin
# config system for an example (lib/defaults.rb)
def load_config(config, config_hash)
  config_hash.each do |name, value|
    levels = name.split('.')
    final = levels.pop

    set_point = levels.inject(config) {|conf, val| conf.send(val) }
    set_point.send(final + '=', value)
  end
end
