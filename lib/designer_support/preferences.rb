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
  module DesignerSupport
    module Preferences
      @backer = java.util.prefs.Preferences.user_node_for_package(Java::dashfx.lib.data.InitInfo.java_class)
      bool = {get: @backer.method(:get_boolean),set: @backer.method(:put_boolean), default: false}
      int = {get: @backer.method(:get_int),set: @backer.method(:put_int), default: 0}
      string = {get: @backer.method(:get),set: @backer.method(:put), default: ""}
      control = {get: @backer.method(:get),set: @backer.method(:put), default: "", map: lambda{|x| SD::Plugins::ControlInfo.find x}}
      array = {get: @backer.method(:get),set: @backer.method(:put), default: "--- []\n", map: lambda{|x| YAML.load x}, unmap: lambda{|x| YAML.dump x}}


      module_function # C++ style "everything after this is a module function"

      {
        team_number_auto: {type: bool, default: true},
        team_number: {type: int},
        root_canvas: {type: control, default: "Canvas"},
        aa_policy: {type: string, default: "regex"},
        aa_regex: {type: string, default: "^SmartDashboard"},
        aa_code: {type: string, default: "return false;"},
        toolbox_icons: {type: string, default: "Icons&Text"},
        defaults_type_number: {type: control, default: "Raw Slider"},
        defaults_type_string: {type: control, default: "Label"},
        defaults_type_bool: {type: control, default: "RedGreen"},
        recently_open: {type: array},
        add_labels: {type: bool, default: true}
      }.each do |key, value|
        # getters
        define_method key do
          meths = value[:type]
          result = if @backer.keys.include? key.to_s
            meths[:get].call(key.to_s, meths[:default])
          else
            value[:default]
          end
          if meths[:map]
            meths[:map].call (result || value[:default] || meths[:default])
          else
            result
          end
        end
        # setters
        define_method "#{key}=" do |newv|
          value[:type][:set].call(key.to_s, value[:type][:unmap] ? value[:type][:unmap].call(newv) : newv)
        end

        module_function key, "#{key}="
      end

      def delete!(key)
        @backer.remove(key.to_s)
      end

      def has_key?(key)
        @backer.keys.include? key.to_s
      end
    end
  end
end
