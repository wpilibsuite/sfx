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

  def initialize(prefs, main)
    @prefs = prefs
    @main = main
    @diffs = {}
    prep_diff(@auto_detect_team, "team_number_auto", :bool, true) do |value|
      if value
        @team_number.text = ""
      end
      @team_number.disabled = value
    end
    prep_diff(@team_number, "team_number", :int_1)
    std_parts = main.find_toolbox_parts[:standard]
    # TODO: no magic numbers
    number_types = std_parts.find_all{|x|!x["Types"].find_all{|x|(x & 3) != 0}.empty?}
    string_types = std_parts.find_all{|x|!x["Types"].find_all{|x|(x & 4) != 0}.empty?}
    bool_types = std_parts.find_all{|x|!x["Types"].find_all{|x|(x & 0x40) != 0}.empty?}
    prep_diff(@default_number, "defaults_type_number", :combo, "Bad Slider",
      number_types, Proc.new{SD::SSListCell.new}, Proc.new{|x|x["Name"]})
    prep_diff(@default_string, "defaults_type_string", :combo, "Label",
      string_types, Proc.new{SD::SSListCell.new}, Proc.new{|x|x["Name"]})
    prep_diff(@default_bool, "defaults_type_bool", :combo, "xBadx",
      bool_types, Proc.new{SD::SSListCell.new}, Proc.new{|x|x["Name"]})

    @root_layout_pane.items.clear
    @root_layout_pane.items.add_all std_parts.find_all{|x|x["Category"] == "Grouping"}
    @root_layout_pane.set_cell_factory do
      SD::SSListCell.new
    end
    @root_layout_pane.button_cell = SD::SSListCell.new
    @root_layout_pane.value = std_parts.find{|x| x["Name"] == @prefs.get("root_canvas", "Canvas")}
    @root_layout_pane.selection_model.selected_item_property.add_change_listener do |ov, old, new|
      @diffs["root_canvas"] = {type: :root_canvas, value: new}
    end
    @stage.set_on_hiding &method(:diff_and_save)
  end

  def prep_diff(obj, prop_name, type, default=nil, combo_range=nil, cell_factory=nil, combo_map=nil, &block)
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
    when :combo
      obj.items.clear
      obj.items.add_all combo_range
      obj.cell_factory = cell_factory
      obj.button_cell = cell_factory.call
      obj.value = combo_range.find{|x| combo_map.call(x) == @prefs.get(prop_name, default)}
      obj.selection_model.selected_item_property.add_change_listener do |ov, old, new|
        @diffs[prop_name] = {type: type, value: combo_map.call(new)}
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
      when :combo
        @prefs.put(prop, dat[:value])
      when :root_canvas # special case
        @prefs.put(prop, dat[:value]["Name"])
        @main.root_canvas = dat[:value][:proc].call
      end
    end
  end

  def close
    @stage.hide
  end
end


class SD::SSListCell < Java::javafx.scene.control.ListCell
  include JRubyFX
  def updateItem(item, empty)
    super
    if (item != nil)
      self.text = item["Name"]
    else
      self.text = nil
    end
  end
end
