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


require_relative 'designers'

class SD::Designers::FileDesigner
  extend SD::Designers
  include JRubyFX

  designer_for java.io.File # TODO: fake. use path, url or something real
  attr_reader :ui

  def initialize
    @ui = HBox.new
    @text = TextField.new
    @btn = Button.new("...")
    @btn.set_on_action do
      dialog = FileChooser.new
      dialog.title = "Pick an image, any image..."
      dialog.add_extension_filter("All Images", %w{*.png *.jpg *.jpeg *.gif *.bmp})
      dialog.add_extension_filter("All Files", %w{*.*})
      # Prevents the properties dialog from going away
      file = SD::Designer.instance.lock_props { dialog.show_open_dialog(find_stage) }
      unless file == nil
        @text.text = file.path
      end
    end
    HBox.setHgrow(@text, Java::javafx.scene.layout.Priority::ALWAYS)
    @ui.children.add(@text)
    @ui.children.add(@btn)
  end

  def find_stage(root=@ui)
    root.scene.window
  end

	def design(prop)
		@text.textProperty().bindBidirectional(prop.property)
  end
end