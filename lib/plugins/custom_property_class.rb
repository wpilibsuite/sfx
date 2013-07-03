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
  module Plugins
    class CustomPropertyClass
      DEFAULT_MAP = {
        java.lang.String => Java::javafx.beans.property.SimpleStringProperty,
        Java::double => Java::javafx.beans.property.SimpleDoubleProperty,
        Java::int => Java::javafx.beans.property.SimpleIntegerProperty,
        Java::boolean => Java::javafx.beans.property.SimpleBooleanProperty,
      }
      DEFAULT_MAP.default = Java::javafx.beans.property.SimpleObjectProperty
      def self.new(props)
        full_map = props.map{|k, v|
          if v.is_a? String
            {"Name" => k, "Var" => k.snake_case.gsub(" ", "_"), "Ptype" => DEFAULT_MAP[JavaUtilities.get_proxy_class(v)], "Type" => JavaUtilities.get_proxy_class(v), "Description" => "#{k} Property"}
          else
            v["Name"] = k
            v["Type"] = JavaUtilities.get_proxy_class(v["Type"])
            v["Default"] = RubyWrapperBeanAdapter.coerce(v["Default"], v["Type"].java_class) if v["Default"]
            v["Ptype"] = if v["Ptype"]
              JavaUtilities.get_proxy_class(v["Ptype"])
            else
              DEFAULT_MAP[v["Type"]]
            end
            v
          end
        }
        c = Class.new do
          include JRubyFX
          full_map.each do |pdesc|
            fxml_accessor pdesc["Var"].to_sym, pdesc["Ptype"], pdesc["Type"]
          end

          def initialize(full_map)
            @full_map = full_map
            full_map.each do |pdesc|
              send("#{pdesc['Var'].snake_case}=", pdesc["Default"]) if pdesc["Default"]
            end
          end

          add_method_signature :all_methods, [java.lang.String[].java_class]
          def all_methods
            @full_map.map{|k|k["Var"]}
          end

          add_method_signature :designable_for, [java.lang.Object.java_class, java.lang.String.java_class]
          def designable_for(name)
            pdesc = @full_map.find{|x|x["Var"] == name}
            RDesignableProperty.new pdesc["Name"], pdesc["Description"]
          end

          add_method_signature :type_for, [java.lang.Class.java_class, java.lang.String.java_class]
          def type_for(name)
            pdesc = @full_map.find{|x|x["Var"] == name}
            pdesc["Type"].java_class
          end
        end
        c.become_java!
        return c.new(full_map)
      end
    end
  end
end
