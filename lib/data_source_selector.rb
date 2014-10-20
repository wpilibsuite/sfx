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
#require 'utils/url'
require 'designer_support/url_options_designer'


module SD
  class DataSourceSelector
    include JRubyFX::Controller
    fxml "DataSourceSelector.fxml"
    #java_import 'dashfx.lib.data.DataInitDescriptor'

    def initialize(endpoints, &on_save)
      @endpoints = endpoints
			@on_save = on_save
			@ds_list.points = endpoints
			@ds_list.selection_model.selected_item_property.add_change_listener {|new| load_info_pane new }
			# selects the first url, TODO: ?
      #url = SD::Utils::Url.from(epts[0])

      #load_info_pane url
      # Search for all types
#      (Java::dashfx.lib.registers.DataProcessorRegister.get_all.to_a + SD::Plugins.data_sources).each do |e|
#        @all_data_sources.items.add DSSMenuItem.new(DataBuilder.new(e)) {|db| create_url(db)}
#      end

    end

    def load_info_pane(did)
      @url_content.content.uninit_bindings if @url_content.content
     # annote = url.find_class.java_class.annotation(Java::dashfx.lib.controls.DesignableData.java_class)
      (@url_content.content = InitInfoDesigner.new(did))
			#.init_bindings(url.name_property, "#{annote.name}\n#{annote.description}", url.class_name)
    end

    def save_it
#      @url_content.content.uninit_bindings if @url_content.content
#      @core.clear_all_data_endpoints
#      @core.mount_data_endpoint @root_source.value.to_did #TODO: support more
#      @stage.hide
    end
  end

end
