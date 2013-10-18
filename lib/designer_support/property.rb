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
    class Property
      attr_accessor :camel, :name, :description, :type, :property, :object, :method, :related_props, :category
      def initialize(camel, name, description, type, property, object, method, category="General")
        @camel, @name, @description, @type, @property, @object, @method, @category = camel, name, description, type, property, object, method, category
      end

      def find(name)
        @related_props.find{|x|x.camel == name}
      end
    end
  end
end
