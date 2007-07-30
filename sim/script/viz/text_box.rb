module Spin
  module Visualization
    class TextBox
      DEFAULT_BOX_COLORS = {:background => 'black', 
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

        @shown = false
      end

      def set_value(text)
        @text = text
        hide()
        internal_draw()
      end

      def select
        @box.set(:outline_color => @rect_colors[:selected]) if @shown && @box
      end

      def unselect
        @box.set(:outline_color => @rect_colors[:unselected]) if @shown && @box
      end

      def hide
        #puts "textbox hide"
        @box.hide    unless @box.nil?
        @box = nil
        @label.hide  unless @label.nil?
        @label = nil
        #@label.set(:text => "")
        #@label.hide.lower_to_bottom
      end

      def show
        #puts "textbox show"
        #@box.raise_to_top.show
        #@label.set(:text => @text)
        #@label.raise_to_top
        @shown = true
        internal_draw
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
                                     :fill_color => @rect_colors[:background],
                                     :outline_color => @rect_colors[:unselected])
        @box.raise_to_top
        @label.raise_to_top
      end
    end  # TextBox

  end  # Vis
end  # Spin
