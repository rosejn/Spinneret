require 'gnome2'
require 'gosim'

$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__)))

require 'viz/manager'
require 'viz/state_renderer'
require 'viz/arc'
require 'viz/text_box'
require 'viz/dht_query'
require 'viz/spin_node'

Spin::Visualization::Manager.instance
