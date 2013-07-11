# Copyright (C) 2013 patrick
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
module SD::DesignerSupport
  class NumberSpinner < Java::JavafxSceneLayout::HBox
    include JRubyFX
    property_accessor :value

    def initialize(min, step, max, log_style=true)
      super()
      @min = min || -1.0/0
      @step = step
      @max = max || 1.0/0
      @log_style = log_style
      @value = simple_double_property(self, "value", 0.0)
      @value.add_change_listener do |new|
        @field.text = new.to_s unless @noback
      end
      font = Font.new("System Bold", 13)

      @field = Java::JavafxSceneControl::TextField.new("0.0")
      @field.setAlignment(Java::javafx::geometry::Pos::CENTER_RIGHT)
      @field.setMaxHeight(1.7976931348623157e+308)
      @field.setPrefWidth(200.0)
      @field.focused_property.add_change_listener do |focused|
        unless focused
          reparse_value
        end
      end

      @field.text_property.add_change_listener do |new|
        @noback = true
        reparse_value
        @noback = false
      end
      Java::JavafxSceneLayout::HBox.setHgrow(@field, Java::javafx::scene::layout::Priority::ALWAYS)

      @minus = Java::JavafxSceneControl::Button.new("-")
      @minus.setFont(font)
      @minus.setMaxHeight(1.7976931348623157e+308)
      @minus.setMinWidth(24)
      @minus.getStyleClass.add("minus")
      @minus.on_mouse_pressed &method(:minus_press)
      @minus.on_mouse_released &method(:released)

      @plus = Java::JavafxSceneControl::Button.new("+")
      @plus.setFont(font)
      @plus.setMaxHeight(1.7976931348623157e+308)
      @plus.setMinWidth(24)
      @plus.getStyleClass.add("plus")
      @plus.on_mouse_pressed &method(:plus_press)
      @plus.on_mouse_released &method(:released)

      getChildren.add_all(@field, @minus, @plus)
      getStyleClass.add("number-spinner")
    end

    def on_press(action, bound)
      reparse_value
      self.value = unless (min..max).include?(stepped = value.send(action, step))
        bound
      else
        stepped
      end
    end

    def minus_press(e)
      on_press(:-, min)
    end

    def plus_press(e)
      on_press(:+, max)
    end

    def step
      if @step == nil
        x = value
        k = 1
        if x > 10
          while x > 10
            x /= 10.0
            k *= 10
          end
          if x < 2
            k /= 10.0
          end
        elsif x == 0
          k = 1
        elsif @log_style
          if x == 1
            k = 0.1
          else
            while x < 1
              x *= 10.0
              k /= 10.0
            end
          end
        else
          k = 1
        end
        k
      else
        step
      end
    end

    def released(e)

    end

    def reparse_value
      self.value = @field.text.to_f
    end

    def min
      if @min.is_a? ObservableValue
        @min.value
      else
        @min
      end
    end
    
    def max
      if @max.is_a? ObservableValue
        @max.value
      else
        @max
      end
    end
  end
end