$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__)))

#require 'breakpoint'  # Fixin' up
require 'benchmark'    # Checkin out
#require 'profile'     # Speedin' up

# Externals
require 'rubygems'
require 'gosim'
require 'zlib'

# Grab the simulation time logger from GoSim
module Base
  include GoSim::Base
end

module KeywordProcessor
  MANDATORY = :MANDATORY

  def process_params(params, defaults)
    result = defaults.dup.update(params)

    # Ensure mandatory params are given.
    unfilled = result.select { |k,v| v == MANDATORY }.map { |k,v| k.inspect }
    unless unfilled.empty?
      msg = "Mandatory keyword parameter(s) not given: #{unfilled.join(', ')}"
      raise ArgumentError, msg
    end

    return result
  end

  def params_to_ivars(params, defaults)
    params = process_params(params, defaults)
    params.each do |k, v|
      instance_variable_set("@" + k.to_s, v) 
    end

    params
  end
end

# Maintenance algorithms
require 'spinneret/maintenance/pull'

# Search algorithms
require 'spinneret/search/kwalker'

# Internals
require 'spinneret/math_ext'
require 'spinneret/link_table'
require 'spinneret/node'
require 'spinneret/analysis'
require 'spinneret/distance_functions'

