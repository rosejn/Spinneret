#require 'breakpoint'  # Fixin' up
require 'benchmark'    # Checkin out
#require 'profile'     # Speedin' up

# Libraries that should be installed.
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

require 'ostruct'

# These should go into the Spinneret namespace
class Scratchpad < OpenStruct
  include Singleton
end

class Configuration < OpenStruct
  include Singleton
end

# Globally needed additions
require 'spinneret/math_ext'

# Maintenance algorithms
require 'spinneret/maintenance/pull'
#require 'spinneret/maintenance/pull_uni'
require 'spinneret/maintenance/push'
require 'spinneret/maintenance/push_pull'
require 'spinneret/maintenance/opportunistic'

# Trim algorithms
require 'spinneret/link_table/base'
require 'spinneret/link_table/rand_upper'

# Search algorithms
require 'spinneret/search/search_base'
require 'spinneret/search/kwalker'
require 'spinneret/search/dht'
require 'spinneret/search/join_query'

# Internals
require 'spinneret/link_table'
require 'spinneret/node'
require 'spinneret/analysis'
require 'spinneret/analysis_helpers'
require 'spinneret/distance_functions'
require 'spinneret/scratchpad'

# Configuration Defaults
require 'defaults'

