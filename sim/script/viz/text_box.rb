module Spin
  module Visualization
    class TextBox
      DEFAULT_BOX_COLORS = {:text => 'black', 
                            :unselected => 'black', 
                            :selected => 'darkgray'}

      def initialize(root, text, x, y, color = 'white', 
                     rect = true, rect_color = DEFAULT_BOX_COLORS)
        @root = root
        @rect = rect
        @rect_colors = rect_color

        @x = x
        @y = y

        @text = text
        @color = color

        internal_draw()
      end

      def set_value(text)
        @label.hide
        @box.hide
        @text = text
        internal_draw()
      end

      def select
        @box.set(:outline_color => @rect_colors[:selected])
      end


      def unselect
        @box.set(:outline_color => @rect_colors[:unselected])
      end

      def hide
        @box.hide
        @label.hide
      end

      def show
        @box.show
        @label.show
      end

      def height
        return @y + @label.text_height
      end

      private

      def internal_draw
        @label = Gnome::CanvasText.new(@root, 
                                       :x => @x, :y => @y, 
                                       :fill_color => @color,
                                       :anchor => Gtk::ANCHOR_NORTH,
                                       :size_points => 8,
                                       :text => @text)
        w = @label.text_width
        @box = Gnome::CanvasRect.new(@root, :x1 => @x - (w / 2 + 4), :y1 => @y,
                                     :x2 => @x + w / 2 + 4,  
                                     :y2 => @y + @label.text_height,
                                     :fill_color => @rect_colors[:text],
                                     :outline_color => @rect_colors[:unselected])
        @box.raise_to_top
        @label.raise_to_top
      end
    end  # TextBox

  end  # Vis
end  # Spin
