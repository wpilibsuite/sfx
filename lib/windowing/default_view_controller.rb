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
    class DefaultViewController
      attr_accessor :tab, :name
      attr_reader :layout_manager
      def initialize
        @name = "general"
        self.root_canvas = SD::DesignerSupport::Preferences.root_canvas.new
        # load default prefs
        SD::DesignerSupport::AAFilter.parse_prefs
      end

      def pane
        @canvas
      end

      def ui
        @canvas.ui
      end

      def root_canvas=(cvs)
        if @canvas
          childs = @canvas.children.to_a
          @canvas.children.clear
          cvs.children.add_all(childs)
        end
        @canvas = cvs
        @layout_manager = SD::Windowing::LayoutManager.new(cvs)
        cvs.ui.style = "" # TODO: hack
      end

      def should_add?(name, all)
        SD::DesignerSupport::AAFilter.filter(name, all)
      end
    end
  end
end
