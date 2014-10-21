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
    @@data_sources = []
    @@decorators = []

    module_function
    def load(location, loader)
      yml = YAML::load_stream(loader.call("/manifest.yml").open_stream.to_io)
      yml = yml[0] if yml.is_a? Array and yml.length == 1
      unless SUPPORTED_API.include? yml['API']
        raise VersionError, "Manifest API is not compatible with this version. Expecting #{SUPPORTED_API} but got #{yml['API']}", caller
      end
      yml["Controls"] = (yml['Controls'] || []).map do |cdesc|
        if cdesc.keys.include? "List Class"
          JavaUtilities.get_proxy_class(cdesc["List Class"]).all.map{|x|JavaControlInfo.new loader, x}
        elsif cdesc.keys.include? "Package"
          # TODO: evil
        elsif cdesc.keys.include? "Class"
          if cdesc['Class'][0].downcase == cdesc['Class'][0] # lowercase = package name => java
            JavaControlInfo.new(loader, JavaUtilities.get_proxy_class(cdesc['Class']).java_class, cdesc)
          else
            RubyControlInfo.new(loader, cdesc)
          end
        else
          ControlInfo.new(loader, cdesc)
        end
      end.flatten

      yml["Decorators"] = (yml["Decorators"] || []).map do |cdesc|
        if cdesc.keys.include? "Listed Decorators"
          cdesc["Listed Decorators"].map{|x|JavaUtilities.get_proxy_class(x)}
        end
      end.flatten

      yml["Data Sources"] = (yml['Data Sources'] || []).map do |cdesc|
        if cdesc.keys.include? "List Class"
          JavaUtilities.get_proxy_class(cdesc["List Class"]).all
				else
					JavaUtilities.get_proxy_class(cdesc["Class"]).java_class
				end
			end.flatten

      yml["View Controllers"] = (yml['View Controllers'] || []).map { |cdesc| ViewControllerInfo.new(cdesc) }

      plug = PluginInfo.new(loader, location, yml)
      @@plugins[plug.plugin_id] = plug
      plug.controls.each{|x|@@controls[x.name]= x}
      @@view_ctrls += plug.view_controllers
      @@data_sources += plug.data_sources
      @@decorators += plug.decorators
    end

    def plugin(uuid)
      @@plugins[uuid]
    end

    def plugins
      @@plugins.values
    end

    def data_sources
      @@data_sources
    end

    def decorators
      @@decorators
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
