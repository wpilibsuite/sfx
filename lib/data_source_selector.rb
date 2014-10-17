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
require 'utils/url'
require 'designer_support/url_options_designer'

module SD
  class DataSourceSelector
    include JRubyFX::Controller
    fxml "DataSourceSelector.fxml"
    java_import 'dashfx.lib.data.DataInitDescriptor'
    java_import 'dashfx.lib.data.InitInfo'

    def initialize(core)
      @core = core
      # TODO: clean this up
      @all_combos = {
        :in => [@root_source],
        #:out => [@root_sink]
      }
      @combo_infos = {
        :in => [{selected: 0, items: ["None"]}],
        # :out => [{selected: 0, items: ["None"]}],
      }

      # input sanitizations, these should be outside so we can do prefs also
      epts = @core.all_data_endpoints
      url = SD::Utils::Url.from(epts[0])

      # TODO: evil
      [@root_source].each do |cb| # root_sink
        combo_init cb
      end
      # TODO: should we use bindings?  yes, except the combo box is special...
      @root_source.items.clear
      @root_source.items.add(url)
      @root_source.selection_model.clear_and_select(0)
      load_info_pane url
      @all_data_sources.items.clear
      # Search for all types
      (Java::dashfx.lib.registers.DataProcessorRegister.get_all.to_a + SD::Plugins.data_sources).each do |e|
        @all_data_sources.items.add DSSMenuItem.new(DataBuilder.new(e)) {|db| create_url(db)}
      end

    end

    def create_url(db)
      url = db.new
      @all_combos.each do |io, vals|
        vals.each do |cb|
          cb.items << url
        end
      end
      @root_source.selection_model.select_last
    end

    def load_info_pane(url)
      @url_content.content.uninit_bindings if @url_content.content
      annote = url.find_class.java_class.annotation(Java::dashfx.lib.controls.DesignableData.java_class)
      (@url_content.content = InitInfoDesigner.new(url)).init_bindings(url.name_property, "#{annote.name}\n#{annote.description}", url.class_name)
    end

    def combo_init(combo)
      combo.set_cell_factory do |param|
        SD::DSSListCell.new
      end
      combo.button_cell = SD::DSSListCell.new
      combo.value_property.add_change_listener do
        next if @ignore_it

        load_info_pane combo.value
      end
    end

    def save_it
      @url_content.content.uninit_bindings if @url_content.content
      @core.clear_all_data_endpoints
      @core.mount_data_endpoint @root_source.value.to_did #TODO: support more
      @stage.hide
    end
  end

  class DSSListCell < Java::javafx.scene.control.ListCell
    include JRubyFX
    def updateItem(item, empty)
      super
      if item
        text_property.bind item.name_property
      else
        text_property.unbind
        self.text = nil
      end
    end
  end

  class DSSMenuItem < Java::JavafxSceneControl::MenuItem
    def initialize(db, &on_action)
      super()
      self.text = db.name
      @db = db
      on_action {|e| on_action.call(db, e)}
    end
  end

  class DataBuilder
    def initialize(e)
      @rclass = e.ruby_class
      @annote = e.annotation(Java::dashfx.lib.controls.DesignableData.java_class)
    end
    def new
      SD::Utils::Url.new("New #{name}", @rclass, nil, nil, "/")
    end
    def name
      @annote.name
    end
    def description
      @annote.description
    end
    def to_s
      @annote.to_s
    end
  end
end
