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

require 'designer_support/plugin_info'

class SD::DesignerSupport::PluginManager
  include JRubyFX::Controller
  fxml "PluginManager.fxml"

  def initialize
    @list.set_cell_factory do
      SD::DesignerSupport::PluginInfoCell.new
    end
    @list.items.add_all SD::Plugins.plugins
    @list.selection_model.selected_item_property.add_change_listener do |v, o, new|
      disp(new)
    end
    @list.selection_model.clear_and_select(0)
  end

  def disp(obj)
    @name.text = obj.name
    @desc.text = obj.description
    @uuid.text = obj.plugin_id
    @version.text = obj.version
    @api_version.text = obj.api.to_s
    @llocation.text = obj.location || "Unknown"
    @contents.text = obj.controls.map(&:name).join("\n")
  end
end
