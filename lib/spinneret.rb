$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__)))

#require 'breakpoint'  # Fixin' up
require 'benchmark'    # Checkin out
#require 'profile'     # Speedin' up

# Externals
require 'rubygems'
require 'gosim'
require 'zlib'

# Internals
require 'spinneret/link_table'
require 'spinneret/node'
require 'spinneret/analysis'
require 'spinneret/distance_functions'

