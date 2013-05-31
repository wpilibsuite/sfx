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

class SD::DesignerSupport::AATreeCell < Java::javafx.scene.control.TreeCell
  def initialize(&block)
    super
    set_on_drag_detected do |e|
        # This block is called when we launch the toolbox, currently a begining of a drop
        db = startDragAndDrop(TransferMode::COPY);

        content = ClipboardContent.new
        content.putString("AutoAdd:#{tree_item.value}");
        db.setContent(content);

        e.consume();
    end
  end

  def updateItem(strtext, empty)
      super
    if !empty && !editing?
      self.text = item.to_s
      self.graphic = tree_item.graphic
    end
  end
end
