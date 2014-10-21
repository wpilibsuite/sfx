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

require 'designer_support/url_options_designer'


module SD
  class DataSourceSelector
    include JRubyFX::Controller
    fxml "DataSourceSelector.fxml"

    def initialize(endpoints, &on_save)
      @endpoints = endpoints
			@on_save = on_save
			@ds_list.points = endpoints
			@ds_list.selection_model.selected_item_property.add_change_listener {|new| load_info_pane new }

      # Search for all types
#      (Java::dashfx.lib.registers.DataProcessorRegister.get_all.to_a + SD::Plugins.data_sources).each do |e|
#        @all_data_sources.items.add DSSMenuItem.new(DataBuilder.new(e)) {|db| create_url(db)}
#      end

    end

    def load_info_pane(did)
      @url_content.content.uninit_bindings if @url_content.content
     # annote = url.find_class.java_class.annotation(Java::dashfx.lib.controls.DesignableData.java_class)
      @url_content.content = InitInfoDesigner.new(did)
			# TODO: bindings are a better idea
			@url_content.content.on_url do |url|
				@ds_list.hack_update_all(url) #bug in jfx7 that we must work around in regard to list updates, so just do it manually
			end
			#.init_bindings(url.name_property, "#{annote.name}\n#{annote.description}", url.class_name)
    end

  end

end
