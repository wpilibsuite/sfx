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
  module IOSupport
    class DashObject
      attr_accessor :object, :children, :props, :sprops
      def initialize(obj, children, props, sprops)
        @object = obj
        @children = children
        @props = props
        @sprops = sprops
      end

      def self.parse_scene_graph(root)
        self.new(root.class, root.children.map{|x| self.parse_object x}, [], [])
      end

      def self.parse_object(elt)
        self.new(elt.original_name, elt.pane? ? elt.child.children.map{|x|parse_object x} : [], elt.export_props, elt.export_static_props)
      end
    end
  end
end
