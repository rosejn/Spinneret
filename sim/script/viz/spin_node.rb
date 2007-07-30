module Spin
  module Visualization

    class DHTQuery < Gnome::CanvasGroup
      def initialize(manager, dest)
        @root = manager.map.root
        @manager = manager

        @dest = dest
        @paths = []
        @pts = []

        @shown = false
      end

      def extend_path(src, dest)
        p "src #{src} dest #{dest}"

        if !src.nil?
          n1 = @manager.nodes[src]  
          p1 = [n1.x + n1.width/2, n1.y + n1.height/2]
          @pts << p1
        end

        n2 = @manager.nodes[dest]
        p2 = [n2.x + n2.width/2, n2.y + n2.height/2]
        @pts << p2

        if @pts.length > 1
          @paths << Arc.new(@manager, @pts[-2], @pts[-1], "Gold", 2)
          @paths.last.hide  if !@shown
        end
      end

      def show
        @paths.each { | p | p.show }
        @shown = true
      end

      def hide
        @paths.each { | p | p.hide }
        @shown = false
      end
    end


    class Node < Gnome::CanvasGroup
      REPS = ["img/phone.png", "img/laptop.png"]

      NODE_FILL = 'DeepSkyBlue'
      NODE_SELECTED_FILL = 'Green'
      NODE_OUTLINE = 'black'

      LABEL_FILL = 'white'
      BOX_FILL = 'black'
      BOX_OUTLINE = 'darkgray'

      attr_reader   :x, :y, :edges, :height, :width
      attr_accessor :out_degree, :in_degree

      @@nodes = {}

      def out_degree=(num)
        @out_degree = num
        @out_degree_box.set_value("od: #{num}")
      end

      def in_degree=(num)
        @in_degree = num
        @in_degree_box.set_value("id: #{num}")
      end

      def pos(id)
        pos =  id / 1000.to_f
        rad = (pos * 2 * Math::PI - (Math::PI + Math::PI / 2))
        @x = -1.0 * Math::cos(rad) * 250 + 300
        @y = -1.0 * Math::sin(rad) * 250 + 300
      end

      def set_pos(x, y)
        move(x - @x, y - @y)

        @x, @y = x, y
      end

      def redraw_links()
        @links.each_key do | dest |
          remove_link(dest)
          add_link(dest)
        end
      end

      def initialize(manager, id)
        @in_degree = @out_degree = 0

        @manager = manager
        @id = id
        @map = @manager.map

        @links = {}
        @queries = {}

        @@nodes[id] = self

        @view = GoSim::View.instance

        pos(id)

        super(@map.root, :x => @x, :y => @y) 

        draw_rep()

        @selected = false
        @failed = false

        signal_connect("event") do | item, event |
          if event.event_type == Gdk::Event::BUTTON_PRESS && event.button == 1
            @selected ? deselect : select
          end
        end

        show_out_degree()
        hide_out_degree()

        show_in_degree()
        hide_in_degree()
      end

      def draw_rep()
        if(@manager.use_graphics)
          @@last_rep ||= 0
          im = Gdk::Pixbuf.new(REPS[@@last_rep])
          @@last_rep = (@@last_rep + 1) % REPS.length
          @width = im.width
          @height = im.height
          image = Gnome::CanvasPixbuf.new(self,
                                          :pixbuf => im,
                                          :x => 0,
                                          :y => 0,
                                          :width => im.width,
                                          :height => im.height,
                                          :anchor => Gtk::ANCHOR_NORTH_WEST)


        else
          @size = 10
          @circle = Gnome::CanvasEllipse.new(self, 
                                             :fill_color => NODE_FILL,
                                             :outline_color => NODE_OUTLINE, 
                                             :x1 => 0, :x2 => @size,
                                             :y1 => 0, :y2 => @size)
          @width = @height = @size
        end

        @label = TextBox.new(self, "#{@id.to_s}", @width / 2, @height + 2)
      end

      def add_link(dest_nid)
        dest_node = @@nodes[dest_nid]
        dest = [dest_node.x + dest_node.width/2, dest_node.y + dest_node.height/2]

        link = Arc.new(@manager, [@x + @width/2, @y + @height/2], dest, "Red", 3)
        link.lower_to_bottom.raise(1)
        link.hide if !@selected
        @links[dest_nid] = link
      end

      def remove_link(dest_nid)
        @links.delete(dest_nid).hide
      end

      def select
        @selected = true

        raise_to_top
        @label.select

        if(!@manager.use_graphics)
          @circle.set(:fill_color => NODE_SELECTED_FILL)
        end

        @links.each_value { | l | l.show }  if !@failed
      end

      def deselect
        @selected = false

        @label.unselect

        if(!@manager.use_graphics)
          @circle.set(:fill_color => NODE_FILL)
        end

        @links.each_value { | l  | l.hide }
      end

      def fail
        @failed = true

        Gnome::CanvasLine.new(self, :points => [[0,0], [@width, @height]],
                              :fill_color => "Red",
                              :width_units => 2)
        Gnome::CanvasLine.new(self, :points => [[@width,0], [0, @height]],
                              :fill_color => "Red",
                              :width_units => 2)
        @links.each_value { | l  | l.hide }
      end


      def show_out_degree
        @out_degree_box ||= TextBox.new(self, "od: #{@out_degree.to_s}", 
                                      @width / 2 + 40, @height - 10)
        @out_degree_box.show
      end

      def hide_out_degree
        @out_degree_box.hide
      end

      def show_in_degree
        @in_degree_box ||= TextBox.new(self, "id: #{@in_degree.to_s}", 
                                      @width / 2 + 40, @height + 10)
        @in_degree_box.show
      end

      def hide_in_degree
        @in_degree_box.hide
      end

    end

  end  #Vis
end  # Spin

