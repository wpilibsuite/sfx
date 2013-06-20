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

require 'yaml'
require "plugins/control_info"
require "plugins/plugin_info"

module SD
  module Plugins
    SUPPORTED_API = [0.1]
    @@plugins = {}
    @@controls = {}
    @@view_ctrls = []

    module_function
    def load(location, loader)
      yml = YAML::load_stream(loader.call("/manifest.yml").open_stream.to_io)
      yml = yml[0] if yml.is_a? Array and yml.length == 1
      unless SUPPORTED_API.include? yml['API']
        raise VersionError, "Manifest API is not compatible with this version. Expecting #{SUPPORTED_API} but got #{yml['API']}", caller
      end
      yml["Controls"] = (yml['Controls'] || []).map do |cdesc|
        if cdesc.keys.include? "List Class"
          JavaUtilities.get_proxy_class(cdesc["List Class"]).all.map{|x|JavaControlInfo.new x}
        elsif cdesc.keys.include? "Package"
          # TODO: evil
        elsif cdesc.keys.include? "Class"
          # TODO: evil
        else
          ControlInfo.new(loader, cdesc)
        end
      end.flatten

      yml["View Controllers"] = (yml['View Controllers'] || []).map { |cdesc| ViewControllerInfo.new(cdesc) }

      plug = PluginInfo.new(loader, location, yml)
      @@plugins[plug.plugin_id] = plug
      plug.controls.each{|x|@@controls[x.name]= x}
      @@view_ctrls += plug.view_controllers
    end

    def plugin(uuid)
      @@plugins[uuid]
    end

    def plugins
      @@plugins.values
    end

    def control(id)
      @@controls[id]
    end

    def controls
      @@controls.values
    end

    def view_controllers
      @@view_ctrls
    end
  end
end
