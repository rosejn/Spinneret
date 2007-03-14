module Spin
  module Visualization
    class Manager
      include Singleton

      attr_reader :map

      def initialize
        @spin_conf = Configuration::instance

        @view = GoSim::View.instance

        @view.add_reset_handler { Spin::Simulation.instance.reset }

        @controls = @view.controls
        @log = @view.log

        @map = @view.space_map
        @nodes = {}

        @edges_visible = false
        @edges = {}

        # Register to handle various datasets
        GoSim::DataSet.add_handler(:node, &method(:handle_node_update))

        # Add custom controls
#        edge_toggle = Gtk::Button.new("Toggle Edges")
#        edge_toggle.signal_connect("clicked") do
#          @edges_visible = !@edges_visible 
#          if @edges_visible
#            @edges.values.each {|e| e.show }
#          else
#            @edges.values.each {|e| e.hide }
#          end
#        end
#        box = Gtk::VBox.new
#        box.pack_start(edge_toggle)
#
#        @controls.add(box)
        @controls.show_all
      end

      def handle_node_update(status, nid, *args)
        case status
        when :new
          x = (nid.to_f / @spin_conf.link_table.address_space)
          @nodes[nid] = Node.new(self, nid, x)
          # add node
        end
      end
    end

    module VizComponent
      SCALE = 500
      OFFSET = 10
      
      def tx(p)
        return p * SCALE + OFFSET
      end
      alias :ty :tx

    end

    class Node < Gnome::CanvasGroup
      include VizComponent

      SIZE = 25

      NODE_FILL = 'DeepSkyBlue'
      NODE_SELECTED_FILL = 'red'
      NODE_OUTLINE = 'black'

      LABEL_FILL = 'white'
      BOX_FILL = 'black'
      BOX_OUTLINE = 'darkgray'

      attr_reader :x, :y, :edges

      def initialize(manager, id, x)
        @manager = manager
        @id = id
        @map = @manager.map


        @edges = []
        @view = GoSim::View.instance

        @x = tx(x)
        @y = 50

        p "new graph node, #{@x} #{@y}"

        super(@map.root, :x => @x, :y => @y) 
        @circle = Gnome::CanvasEllipse.new(self, 
              :fill_color => NODE_FILL, :outline_color => NODE_OUTLINE, 
              :x1 => 0, :x2 => SIZE,
              :y1 => 0, :y2 => SIZE)

        mid = SIZE / 2
        @label = Gnome::CanvasText.new(self, 
                                       :x => mid, :y => SIZE + 2, 
                                       :fill_color => LABEL_FILL,
                                       :anchor => Gtk::ANCHOR_NORTH,
                                       :size_points => 15,
                                       :text => "#{@id.to_s}")# (#{@neighbor_locs.size})")
#        @label.hide
        @label.text_width
        w = @label.text_width
        @box = Gnome::CanvasRect.new(self, :x1 => mid - (w / 2 + 4), :y1 => SIZE + 2,
                                :x2 => mid + w / 2 + 4,  
                                :y2 => SIZE + @label.text_height + 2,
                                :fill_color => BOX_FILL,
                                :outline_color => BOX_OUTLINE) 
        @box.raise_to_top
        @label.raise_to_top
        @box.hide

        signal_connect("event") do | item, event |
          if event.event_type == Gdk::Event::BUTTON_PRESS && event.button == 1
            @selected ? deselect : select
          end
        end
      end

      def select
        raise_to_top
        @selected = true
        @circle.set(:fill_color => NODE_SELECTED_FILL)
        @label.show
        @box.show
#        @view.set_data([["foo", "bar", 2]], ["c1", "c2", "c3"])
        @edges.each {|e| e.show }
      end

      def deselect
        @selected = false
        @circle.set(:fill_color => NODE_FILL)
        #@label.hide
        @box.hide
        #@view.clear_data
        @edges.each {|e| e.hide }
      end

=begin
      def refresh
        @label.set(:text => "#{@id.to_s} (#{@neighbor_locs.size})")
        if @selected
          hide_links
          draw_links
        end
      end
=end

    end
  end
end

Spin::Visualization::Manager.instance
