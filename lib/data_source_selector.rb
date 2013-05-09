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
      epts = @core.all_data_endpoints
      ep = epts[0]
      @root_source.items.add ep.name
      @root_source.selection_model.clear_and_select 1
      @name.text = ep.name
      @host.text = ep.init_info.host
      annote = ep.object.java_class.annotation(Java::dashfx.controls.DesignableData.java_class)
      @type_info.text = "#{annote.name}\n#{annote.description}"
      @type_classname.text = ep.object.java_class.inspect.sub(/^class /, '')
    end
    
  end
end