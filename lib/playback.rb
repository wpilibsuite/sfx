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
module SD

  class Playback
    include JRubyFX::DSL
    def initialize(data_core, parent_win)
      @core = data_core
      @stage = stage(title: "PlayBack>> Controller") do
        init_owner parent_win
      end
      @core.add_data_filter Java::dashfx.lib.data.endpoints.PlaybackFilter.new.tap{|x| @filter = x}
    end

    def launch
      SD::PlaybackController.load_into @stage, initialize: [@core, @filter]
      @stage.show_and_wait
      @filter.leave_playback
    end
  end

  class PlaybackController
    include JRubyFX::Controller
    fxml "PlaybackEditor.fxml"

    def initialize(core, filter)
      @core = core
      @scale_value = 1.0
      @filter = filter
      @filter.enter_playback
      @slider.max_property.bind @filter.length
      @slider.value_property.bind_bidirectional @filter.pointer
      @playback_src.items.clear
      @playback_src.items.add_all("Live Data",
        *Dir[File.join(Dir.home, ".smartdashboard-playback", "*.sdfxplbk")].tap{|x| @original_src = x}.map{|x|
          File.basename(x, ".sdfxplbk").gsub(/ ([0-9]{1,2})_([0-9]{2})_([0-9]{2}) ([AP]M)/, ' \1:\2:\3 \4')})
      @playback_src.selection_model.clear_and_select(0)
      @playback_src.selection_model.selected_index_property.add_change_listener do |idx|
        if idx == 0
          #hmm, TODO
        else
          load(@original_src[idx-1])
        end
      end
      @log_scale.value_property.add_change_listener do |new|
        @scale_value = logify(new)
        @speed_lbl.text = "#{"%.1f" % @scale_value}x"
      end
    end

    logify_generic = ->(min_out, max_out, min_in, max_in, x) do
      Math::E ** (Math.log(min_out) + ((Math.log(max_out)- Math.log(min_out)) / (max_in - min_in)) * (x - min_in))
    end

    define_method(:logify, logify_generic.curry[0.1, 10, 0, 100])

    def step_1
      if @slider.value < @filter.length.get - 1
        @slider.value += 1
      end
    end

    def step_back_1
      if @slider.value > 0
        @slider.value -= 1
      end
    end

    def to_beginning
      @slider.value = 0
    end

    def to_end
      @slider.value = @filter.length.get
    end

    def kill
      @stage.close
    end

    def play
      @filter.play_with_time
    end

    def yalp
      @filter.play_with_time(-1)
    end

    def stop
      @filter.stop_the_film
    end

    def load(file)
      list, dates = File.open(file, "r") {|f|Marshal.load(f)}
      @filter._impl_load(list.map(&:to_data), dates.map(&:to_java))
    end

    def save
      list, dates = @filter._impl_save
      list = list.map{|x|DiskTransaction.new(x)}
      dates = dates.map{|d|Time.at(d.time/1000.0)}
      timestamp = Time.now.strftime("%F %r -- ")
      dir = File.join(Dir.home, ".smartdashboard-playback")
      Dir.mkdir(dir) unless Dir.exist? dir
      File.open(File.join(dir, timestamp.gsub(":", "_") + ".sdfxplbk"), "w") do |f|
        f << Marshal.dump([list,dates])
      end
      @playback_src.items.add(timestamp)
    end
  end
  class DiskTransaction
    def initialize(trans)
      @deleted = trans.deleted_names.to_a
      @values = trans.values.map{|x|DiskValue.new(x.name, x.group_name, x.type, x.data)}
    end
    def to_data
      Java::dashfx.lib.data.SimpleTransaction.new(@values.map(&:to_data).to_java(Java::dashfx.lib.data.SmartValue), @deleted.to_java(:String))
    end
  end
  class DiskValue
    def initialize(name, group, type, data)
      @name = name
      @group = group
      @type = type && type.mask || 0xFFFFFFFF
      @datat = data.class
      @datav = if data.respond_to? :export_data
        @exp = true
        safe(data.export_data)
      else
        @exp = false
        data.as_raw
      end
    end

    def safe(value)
      if value.respond_to?(:java_class) && value.java_class.array?
        value.map{|x|safe(x)}
      else
        case value
        when java.lang.String then value.to_s
        when java.lang.Double then value.double_value
        when java.lang.Float then value.float_value
        when java.lang.Integer then value.int_value
        when java.lang.Boolean then value.boolean_value
        else value
        end
      end
    end

    def to_data
      Java::dashfx.lib.data.SmartValue.new(@datat.new(@datav), Java::dashfx.lib.data.SmartValueTypes.values.find{|x| x.mask == @type}, @name, @group)
    end
  end
end
