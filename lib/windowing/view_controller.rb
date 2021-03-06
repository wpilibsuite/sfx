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
  module Windowing
    class ViewController
      attr_accessor :ui
      def initialize
        @ui = nil
      end
      def self.vm(name)
        define_method name do
          raise "Virtual method not overridden in #{self}!"
        end
      end
      vm :add
      vm :add_others
      vm :add_new
      vm :global_matched
      vm :should_label?
    end
  end
end
