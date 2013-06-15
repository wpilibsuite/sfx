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
    class PluginInfo < Java::JavafxSceneLayout::BorderPane
      def initialize()
        super
        lbl = nil
        desc = nil
        set_center(vbox(padding: [0, 0, 0, 6]) do
            lbl = label() do
              self.font = font!("System Bold", 13)
            end
            desc = label()
          end)
        @images = image_view(fit_height: 32, fit_width: 32)
        set_left @images
        @name = lbl
        @desc = desc
      end

      def name=(val)
        @name.text = val
      end

      def description=(val)
        @desc.text = val
      end

      def image=(val)
        @images.image = val
      end
    end
    class PluginInfoCell < Java::javafx.scene.control.ListCell
      def initialize
        super
        @info = self.graphic = SD::DesignerSupport::PluginInfo.new
      end
      def updateItem(strtext, empty)
        super
        if !empty && !editing?
          @info.name = item.name
          @info.description = item.description
          icon_url = item.icon_stream
          icon = icon_url.call if icon_url
          @info.image = (icon || image(resource_url(:images, "plugin.png").to_s))
        end
      end
    end
  end
end
