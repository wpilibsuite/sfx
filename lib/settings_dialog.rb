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

class SD::SettingsDialog
  include JRubyFX::Controller
  fxml "Settings.fxml"

  def initialize(prefs)
    @prefs = prefs
    @diffs = {}
    prep_diff(@auto_detect_team, "team_number_auto", :bool, true) do |value|
      if value
        @team_number.text = ""
      end
      @team_number.disabled = value
    end
    prep_diff(@team_number, "team_number", :int_1, true)
    @stage.set_on_hiding &method(:diff_and_save)
  end

  def prep_diff(obj, prop_name, type, default, &block)
    case type
    when :bool
      obj.selected = @prefs.get_boolean(prop_name, default)
      obj.selected_property.add_change_listener do |ov, old, new|
        @diffs[prop_name] = {type: type, value: new}
        if block
          block.call(new)
        end
      end
    when  :int_1
      @prefs.get_int(prop_name, -1).tap {|x|obj.text =  x == -1 ? "" : x.to_s }
      obj.text_property.add_change_listener do |ov, old, new|
        @diffs[prop_name] = {type: type, value: new}
        if block
          block.call(new)
        end
      end
    end
  end

  def diff_and_save(e)
    @diffs.each do |prop, dat|
      case dat[:type]
      when :bool
        @prefs.put_boolean(prop, dat[:value])
      when :int_1
        if dat[:value] == ""
          @prefs.remove(prop)
        else
          @prefs.put_int(prop, dat[:value].to_i)
        end
      end
    end
  end

  def close
    @stage.hide
  end
end
