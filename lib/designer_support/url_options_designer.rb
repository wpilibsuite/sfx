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

module SD
#  class OptionPair
#    include JRubyFX
#    fxml_accessor :name
#    fxml_accessor :value
#    def initialize(name, value)
#      self.name = name
#      self.value = value
#    end
#  end

  class InitInfoDesigner < javafx.scene.layout.VBox
    include JRubyFX::Controller
    fxml "UrlFragment.fxml"

    def initialize(dil)
      @urlo = url
      @protocol = "http"
      @options = observable_array_list()
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
      @host.text = url.host
      @port.text = url.port.to_s
      @path.text = "" # TODO:
      url.options.each do |kv|
        (key, value) = kv
        @options.add(OptionPair.new(key, value))
      end
      # always show the current team-number induced value
      @host.prompt_text = Java::dashfx.lib.data.InitInfo.new.host
      # TODO: bindings?
      @host.text_property.add_change_listener { re_url }
      @port.text_property.add_change_listener { re_url }
      @path.text_property.add_change_listener { re_url }
      children << OptionDesigner.new(@options, ["corn", "brady", "port"])
    end

    def init_bindings(name, type_info, classname)
      @par_name = name
      @name.text_property.bind_bidirectional @par_name
      @type_info.text = type_info
      @type_classname.text = classname
    end

    def uninit_bindings
      @name.text_property.unbind_bidirectional @par_name
      @urlo.host = @host.text
      @urlo.port = @port.text.to_i
      @options.each do |op|
        @urlo.set_option(op.name, op.value)
      end
    end

    def options
      str = @options.map { |itm|
        if itm.name && itm.name != ""
          itm.name + "=" + (itm.value || "")
        else
          nil
        end
      }.find_all {|x| !x.nil?}.join("&")
      if str.length > 0
        "?" + str
      else
        ""
      end
    end

    def hostfix
      if @host.text and @host.text.include? "://"
        @host.text
      else
        "#{@protocol}://#{"#{@host.text}" != "" ? @host.text : "10.xx.yy.2"}"
      end
    end

    def port
      if @port.text.length > 0
        ":#{@port.text}"
      else
        ""
      end
    end

    def path
      "/#{@path.text}".sub(/^\/\//, "/")
    end

    def re_url
      # TODO: bindings and url parsing
      @url.text = hostfix + port + path + options
    end

  end

  class OptionDesigner < javafx.scene.layout.GridPane
    include JRubyFX::Controller
    fxml "OptionFragment.fxml"

    def initialize(list, known)
      @list = observable_array_list(*known)
      @options = list
      @options.each {|pair| add_row pair}
    end

    def add_pair
      pair = OptionPair.new
      add_row(pair)
      @options << pair
    end

    def add_row(pair)
      rowid = row_constraints.length - 1
      with(self) do
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
