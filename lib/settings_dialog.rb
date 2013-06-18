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

require 'designer_support/code_editor'

class SD::SettingsDialog
  include JRubyFX::Controller
  fxml "Settings.fxml"

  def initialize(main)
    # can't do this above or @aa_never and friends are still nil
    @auto_add_options = {
      "never" => @aa_never,
      "regex" => @aa_match_regex,
      "code" => @aa_code
    }
    @prefs = SD::DesignerSupport::Preferences
    @main = main
    @diffs = {}
    prep_diff(@auto_detect_team, "team_number_auto", :bool) do |value|
      if value
        @team_number.text = ""
      end
      @team_number.disabled = value
    end
    prep_diff(@team_number, "team_number", :int_1)

    std_parts = SD::Plugins.controls
    # TODO: no magic numbers
    number_types = std_parts.find_all{|x|!x.types.find_all{|x|(x & 3) != 0}.empty?}
    string_types = std_parts.find_all{|x|!x.types.find_all{|x|(x & 4) != 0}.empty?}
    bool_types = std_parts.find_all{|x|!x.types.find_all{|x|(x & 0x40) != 0}.empty?}
    root_types = std_parts.find_all{|x|x.category == "Grouping"}

    prep_diff(@default_number, "defaults_type_number", :combo,
      number_types, SD::SSListCell)
    prep_diff(@default_string, "defaults_type_string", :combo,
      string_types, SD::SSListCell)
    prep_diff(@default_bool, "defaults_type_bool", :combo,
      bool_types, SD::SSListCell)
    prep_diff(@root_layout_pane, "root_canvas", :combo,
      root_types, SD::SSListCell, Proc.new{|dat|
        @main.root_canvas = dat[:raw_value].new})

    @aa_regex.text = @prefs.aa_regex
    @aa_code_code = @prefs.aa_code

    (@auto_add_options[@prefs.aa_policy] || @aa_never).tap do |si|
      si.selected = true
      @aa_regex.disable = si != @aa_match_regex
    end

    @stage.set_on_hiding &method(:diff_and_save)
  end

  # prepare each type of item
  def prep_diff(obj, prop_name, type, combo_range=nil, cell_class=nil, on_save=nil, &block)
    case type
    when :bool
      obj.selected = @prefs.send(prop_name)
      obj.selected_property.add_change_listener do |ov, old, new|
        @diffs[prop_name] = {type: type, value: new}
        if block
          block.call(new)
        end
      end
    when :int_1
      obj.text = @prefs.has_key?(prop_name) ? @prefs.send(prop_name).to_s : ""
      obj.text_property.add_change_listener do |ov, old, new|
        @diffs[prop_name] = {type: type, value: new}
        if block
          block.call(new)
        end
      end
    when :combo
      obj.items.clear
      obj.items.add_all combo_range
      obj.cell_factory = Proc.new{cell_class.new}
      obj.button_cell = cell_class.new
      obj.value = combo_range.find{|x| x.id == @prefs.send(prop_name).id}
      obj.selection_model.selected_item_property.add_change_listener do |ov, old, new|
        @diffs[prop_name] = {type: type, value: new.name, raw_value: new, on_save: on_save}
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
        @prefs.send(prop + "=", dat[:value])
      when :int_1
        if dat[:value] == ""
          @prefs.delete(prop)
        else
          @prefs.send(prop + "=", dat[:value].to_i)
        end
      when :combo
        @prefs.send(prop + "=", dat[:value])
        dat[:on_save].call(dat) if dat[:on_save]
      when :aa_radio
        @prefs.send(prop + "=", dat[:value])
        @prefs.send("aa_regex=", @aa_regex.text)
        @prefs.send("aa_code=", @aa_code_code) if @aa_code_code != "return false;"
        SD::DesignerSupport::AAFilter.parse_prefs
      end
    end
  end

  def close
    @stage.hide
  end

  def aa_combo_change
    st = @aa_match_regex.toggle_group.selected_toggle
    @aa_regex.disable = st != @aa_match_regex
    @aa_code_btn.disable = st != @aa_code
    @diffs["aa_policy"] = {type: :aa_radio, value: @auto_add_options.invert[st], regex: @aa_regex.text, code: @aa_code_code}
  end

  def aa_edit_code
    res = SD::DesignerSupport::CodeEditor.show_and_wait(@stage, @aa_code_code)
    if res
      @aa_code_code = res
      @diffs["aa_policy"] = {type: :aa_radio, value: @auto_add_options.invert[@aa_match_regex.toggle_group.selected_toggle], regex: @aa_regex.text, code: @aa_code_code}
    end
  end

  def plugin_manager
    stg = @stage
    stage(init_style: :utility, init_modality: :app, title: "Plugin Manager") do
      init_owner stg
      fxml SD::DesignerSupport::PluginManager
      show_and_wait
    end
  end
end


class SD::SSListCell < Java::javafx.scene.control.ListCell
  include JRubyFX
  def updateItem(item, empty)
    super
    if (item != nil)
      self.text = item.name
    else
      self.text = nil
    end
  end
end
