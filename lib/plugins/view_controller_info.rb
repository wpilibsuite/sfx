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
    class ViewControllerInfo
      attr_reader :max, :default
      def initialize(hash)
        @pclass = JavaUtilities.get_proxy_class(hash["Class"])
        @addable = hash["Addable"] || true
        @max = hash["Max"] || Float::INFINITY
        @default = hash["Default"] || 0
        @closable = hash["Closable"] || true
      end

      def addable?
        @addable
      end

      def closable?
        @closable
      end

      def new
        @pclass.new
      end
    end
    class DataSourceInfo
      def self.new(hash)
        JavaUtilities.get_proxy_class(hash["Class"]).tap{|x| p x}.java_class
      end

      def new
        @pclass.new
      end
    end
  end
end


=begin
View Controllers:
-
  Class: dashfx.livewindow.LiveWindowViewController
  Addable: false
  Max: 1
  Default: 1
  Closable: false
=end