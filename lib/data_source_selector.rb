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
  class DataSourceSelector
    include JRubyFX::Controller
    fxml_root "res/DataSourceSelector.fxml"

    def initialize(core)
      @core = core
      @all_combos = {
        :in => [@root_source],
        :out => [@root_sink]
      }
      @combo_infos = {
        :in => [{selected: 0, items: ["None"]}],
        :out => [{selected: 0, items: ["None"]}],
      }
      @combo_taints = []
      @combo_bottoms = []
      epts = @core.all_data_endpoints
      ep = epts[0]
      [@root_source, @root_sink].each do |cb|
        combo_init cb
      end
      # TODO: should we use bindings?  yes, except the combo box is special...
      combo_add :current, ep, :in, 0
      @name.text_property.bind_bidirectional ep.name_property
      @name.set_on_action &method(:update_combo_view)
      @host.text = ep.init_info.host
      annote = ep.object.java_class.annotation(Java::dashfx.controls.DesignableData.java_class)
      @type_info.text = "#{annote.name}\n#{annote.description}"
      @type_classname.text = ep.object.java_class.inspect.sub(/^class /, '')
      # Search for all types
      Java::dashfx.registers.DataProcessorRegister.get_all.each do |e|
        combo_add :new_type, [e.annotation(Java::dashfx.controls.DesignableData.java_class), e]
      end
      combo_flush
    end
    
    def update_combo_view(e)
      # TODO: its probbably better to search for the ones that need redrawing and force just that.
      @all_combos.each do |k, its|
        its.each do |combo|
          ix = combo.selection_model.selected_index
          combo.selection_model.clear_and_select 0
          combo.selection_model.clear_and_select ix
        end
      end
    end
    
    def combo_init(combo)
      combo.set_cell_factory do |param|
        SD::DSSListCell.new
      end
      combo.button_cell = SD::DSSListCell.new
    end
    
    def combo_flush
      if @combo_taints.include? :all
        # TODO: may not be square
        @combo_taints = ([:in, :out].product (0...@combo_infos[:in].length).to_a)
      end
      @combo_taints.each do |comb, idx|
        combo = @all_combos[comb][idx]
        data = @combo_infos[comb][idx]
        combo.items.clear
        combo.items.add_all data[:items]
        combo.items.add :seperator
        combo.items.add_all @combo_bottoms
        combo.selection_model.clear_and_select data[:selected]
      end
    end
    
    def combo_add(type, value, combo=nil, indx=nil)
      case type
      when :current, :possible
        cin = @combo_infos[combo][indx]
        cin[:items] << value
        cin[:selected] = (cin[:items].length - 1) if type == :current
        @combo_taints << [combo, indx]
      when :new_type
        @combo_bottoms << value
        @combo_taints << :all
      else
        puts "EEK! unknown combo add type #{type}"
      end
    end
  end
  
  class DSSListCell < Java::javafx.scene.control.ListCell     
    include JRubyFX
    def updateItem(item, empty)
      super
      if (item != nil) 
        self.disabled = false
        self.tooltip = nil
        if item == :seperator
          self.text = "------------"
          self.disabled = true
        elsif item.is_a? Array and item[0].kind_of? Java::dashfx.controls.DesignableData
          self.text = "New #{item[0].name.match(/[\:]?([^\:]*)$/)[1]}"
          self.tooltip = build(Tooltip, item[1].name)
        elsif item.is_a? String
          self.text = item
        else # TODO: don't assume
          self.text = item.name
        end                        
      else
        self.text = nil
      end
    end         
  end
end