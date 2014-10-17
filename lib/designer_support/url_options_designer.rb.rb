# Copyright (C) 2014 patrick
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

require 'jrubyfx'

fxml_root File.join(File.dirname(__FILE__), "../res"), "res"
#resource_root :images, File.join(File.dirname(__FILE__), "res", "img"), "res/img"

module SD
  class App < JRubyFX::Application
    def start(stage)
      with(stage, :title => "SmartDashboard") do
        layout_scene(fill: :pink) do
          url_designer
        end
        #fxml SD::Designer
        #icons.add image(resource_url(:images, "16-fxicon.png").to_s)
        #icons.add image(resource_url(:images, "32-fxicon.png").to_s)
        #fxml SD::URLDesigner
        show
      end
    end
  end

  class OptionPair
    include JRubyFX
    fxml_accessor :name
    fxml_accessor :value
  end

  class InitInfoDesigner

    def initialize
      observable_array_list()
      @options.add_change_listener do |change|
        while change.next
          if change.wasAdded
            change.added_sub_list.each do |asl|
              asl.name_property.add_change_listener { re_url }
              asl.value_property.add_change_listener { re_url }
            end
          end
        end
        re_url
      end
    end

    def re_url
      puts @options.map { |itm|
        if itm.name && itm.name != ""
          itm.name + "=" + (itm.value || "")
        else
          nil
        end
      }.find_all {|x| !x.nil?}.join("&")
    end

  end

  class OptionDesigner < javafx.scene.layout.GridPane
    include JRubyFX::Controller
    fxml "OptionFragment.fxml"
    register_type self, "url_designer"

    def initialize(list, known)
      @list = observable_array_list(*known)
      @options = list
    end

    def add_pair
      rowid = row_constraints.length - 1
      with(self) do
        pair = OptionPair.new
        tf = text_field(promptText: "Value")
        tf.text_property.bind_bidirectional(pair.value_property)

        cb = combo_box(editable: true, maxWidth: java.lang.Double::MAX_VALUE, promptText: "Name", items: @list)
        cb.value_property.bind_bidirectional(pair.name_property)

        x = button("X", prefHeight: 16, prefWidth: 16, style: "-fx-background-color: transparent;-fx-margin: 0; -fx-padding: 0;")

        x.set_on_action do |e|
          delete_row GridPane.getRowIndex(e.source), pair
        end
        row_constraints.add(rowid, build(RowConstraints, minHeight: -Float::INFINITY, prefHeight: -1.0, vgrow: Priority::SOMETIMES))
        GridPane.setRowIndex(@add_btn, rowid + 1)
        self.addRow(rowid, cb, tf, x)
        @options << pair
      end
    end

    def delete_row(idx, pair)
      the_row = []
      children.each do |x|
        xix = GridPane.getRowIndex(x)
        case xix
        when (-1...idx)
        when idx
          the_row << x
        else
          GridPane.setRowIndex(x, xix-1)
        end
      end
      the_row.each{|x| children.remove x}
      row_constraints.remove idx
      @options.remove(pair)
    end
  end
end

SD::App.launch