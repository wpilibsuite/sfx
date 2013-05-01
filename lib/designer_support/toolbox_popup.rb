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


module SD::DesignerSupport
  class ToolboxPopup < Java::javafx::stage::Popup
    def initialize
      super
      @pane = ToolboxPane.new self
      content.add(@pane)
    end

    def add(item)
      @pane.tb_area.add(item)
    end
  end
  class ToolboxPane < Java::javafx::scene::layout::BorderPane
    include JRubyFX::Controller
    fxml_root "../res/ToolboxPopup.fxml"
    attr_reader :tb_area

    def initialize(parent)
      @popup = parent
    end

    def close
      @popup.hide
    end
  end
end

