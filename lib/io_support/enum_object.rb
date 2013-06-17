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

require 'io_support/complex_object'

module SD
  module IOSupport
    class EnumObject < ComplexObject
      attr_accessor :enum_class, :value
      def initialize(eval)
        @enum_class = eval.class
        @value = eval.to_s
      end

      def to_value
        @enum_class.value_of @value
      end
    end
  end
end
