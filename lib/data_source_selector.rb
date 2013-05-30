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
    fxml "DataSourceSelector.fxml"
    java_import 'dashfx.lib.data.DataInitDescriptor'
    java_import 'dashfx.lib.data.InitInfo'

    def initialize(core)
      @core = core
      @all_combos = {
        :in => [@root_source],
        #:out => [@root_sink]
      }
      @combo_infos = {
        :in => [{selected: 0, items: ["None"]}],
       # :out => [{selected: 0, items: ["None"]}],
      }
      @combo_taints = []
      @combo_bottoms = []
      epts = @core.all_data_endpoints
      ep = epts[0]
      [@root_source].each do |cb| # root_sink
        combo_init cb
      end
      # TODO: should we use bindings?  yes, except the combo box is special...
      combo_add :current, ep, :in, 0
      @name.text_property.bind_bidirectional ep.name_property
      @old_np = ep.name_property
      @name.set_on_action &method(:update_combo_view)
      @host.text = ep.init_info.host
      annote = ep.object.java_class.annotation(Java::dashfx.lib.controls.DesignableData.java_class)
      @type_info.text = "#{annote.name}\n#{annote.description}"
      @type_classname.text = ep.object.java_class.inspect.sub(/^class /, '')
      # Search for all types
      Java::dashfx.lib.registers.DataProcessorRegister.get_all.each do |e|
        combo_add :new_type, [e.annotation(Java::dashfx.lib.controls.DesignableData.java_class), e]
      end
      combo_flush
    end

    def load_info_pane(did)
      @name.text_property.unbind_bidirectional @old_np
      @name.text_property.bind_bidirectional did.name_property
      @old_np = did.name_property
      @host.text = did.init_info.host
      annote = did.object.java_class.annotation(Java::dashfx.lib.controls.DesignableData.java_class)
      @type_info.text = "#{annote.name}\n#{annote.description}"
      @type_classname.text = did.object.java_class.inspect.sub(/^class /, '')
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
      combo.value_property.add_change_listener do
        next if @ignore_it
        if @smash_quiet #TODO: why do I need to do this?
          @smash_quiet.call
          @smash_quiet = nil
        end

        item = combo.value
        if item == :seperator
          loc = :in
          idx = @all_combos[loc].index(combo)
          # TODO: figure out strange sections
          combo_select @combo_infos[loc][idx][:selected], loc, idx
          combo_flush
        elsif item.is_a? Array and item[0].kind_of? Java::dashfx.lib.controls.DesignableData
          job = item[1].ruby_class.new
          did = DataInitDescriptor.new(job, item[0].name.match(/[\:]?([^\:]*)$/)[1], InitInfo.new(), nil)
          # TODO: check if its in/out, just out, or just in
          @all_combos[:in].length.times do |idx|
            combo_add (@all_combos[:in][idx] == combo ? :current : :possible), did, :in, idx
          end
          combo_flush
        elsif item.is_a? String
          # nothing exciting
        elsif item # TODO: don't assume
          # reload the info pane
          load_info_pane item
        end
      end
    end

    def combo_flush
      if @combo_taints.include? :all
        # TODO: may not be square
        @combo_taints = ([:in].product (0...@combo_infos[:in].length).to_a) # TODO: out
      end
      @combo_taints.each do |comb, idx|
        combo = @all_combos[comb][idx]
        data = @combo_infos[comb][idx]
        @ignore_it = true
        @smash_quiet = Proc.new do
                  combo.selection_model.select combo.items[data[:selected]]
        end
        combo.items.clear
        combo.items.add_all data[:items]
        combo.items.add :seperator
        combo.items.add_all @combo_bottoms
        combo.selection_model.select combo.items[data[:selected]]
        @ignore_it = false
      end
      @combo_taints = []
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

    def combo_select(selected, combo, indx)
      @combo_infos[combo][indx][:selected] = selected
      @combo_taints << [combo, indx]
    end

    def save_it
      @core.clear_all_data_endpoints
      @root_source.value.mount_point = @root_url.text
      @core.mount_data_endpoint @root_source.value
      @stage.hide
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
        elsif item.is_a? Array and item[0].kind_of? Java::dashfx.lib.controls.DesignableData
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