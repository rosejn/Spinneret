module Spin
  module Visualization
    module StateRenderer
      ItemState = Struct.new(:dirty, :func)

      def render_init
        @state = {}
      end

      def render
        @state.each_value do | item | 
          if item.dirty
            item.func.call() 
            item.dirty = false
          end
        end
      end

      def dirty(*names)
        names.each do | name |
          if @state.key? name
            @state[name].dirty = true  
          else
            puts "Unknown render key :#{name}"  if VizSettings::instance.debug
          end
        end
      end

      def add_render_item(name, &block)
        @state[name] = ItemState.new(false, block)
      end

      def remove_render_item(name)
        @state.delete(name)
      end

    end
  end
end
