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
      @core.add_data_filter Java::dashfx.data.endpoints.PlaybackFilter.new.tap{|x| @filter = x}
    end

    def launch
      SD::PlaybackController.load_into @stage, initialize: [@core, @filter]
      @stage.show_and_wait
      @filter.leave_playback
    end
  end

  class PlaybackController
    include JRubyFX::Controller
    fxml_root "PlaybackEditor.fxml"

    def initialize(core, filter)
      @core = core
      @filter = filter
      @filter.enter_playback
      @slider.max_property.bind @filter.length
      @slider.value_property.bind_bidirectional @filter.pointer
    end


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
  end
end