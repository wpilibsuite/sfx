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

      def ==(rhs)
        if rhs.respond_to? :object and rhs.respond_to? :children and rhs.respond_to? :props and rhs.respond_to? :sprops
          @object == rhs.object && @children.sort == rhs.children.sort && @props.sort == rhs.props.sort && @sprops.sort == rhs.sprops.sort\
        end
      end

      # TODO: I don't like this special casing
      def self.parse_scene_graph(roots, data_core)
        DataObject.new data_core, roots.map{|vc| DashRoot.new(vc.class, vc.name, vc.pane.children.map{|x|self.parse_object x})}
      end

      def self.parse_object(elt)
        self.new(elt.original_name, elt.save_children? ? elt.child.children.map{|x|parse_object x} : [], elt.export_props, elt.export_static_props)
      end
    end
    class DashRoot
      attr_accessor :vc_class, :name, :children
      def initialize(vc_class, name, children)
        @vc_class = vc_class
        @children = children
        @name = name
      end

      def new
        tmp = @vc_class.new
        tmp.name = @name if @name && tmp.name != @name
        tmp
      end
    end
    class DataObject
      attr_accessor :vcs, :known_names
      def initialize(data, vcs)
        @vcs = vcs
        @known_names = data.known_names.to_a
      end
    end
  end
end
