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
  class OptionPair
    include JRubyFX
    fxml_accessor :name
    fxml_accessor :value
    def initialize(name="", value="")
      self.name = name
      self.value = value
    end
  end

  class InitInfoDesigner < javafx.scene.layout.VBox
    include JRubyFX::Controller
    fxml "UrlFragment.fxml"

    def initialize(dil, list, get_meta)
			@dil = dil
			@get_meta = get_meta
      @urlo = dil.init_info
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
      @host.text = @urlo.raw_host
      @port.text = @urlo.port.to_s
      @path.text = @urlo.path
      @urlo.all_options.each do |(key, value)|
        @options.add(OptionPair.new(key, value))
      end
			
			@type_chooser.button_cell = DTSCell.new(@get_meta)
			@type_chooser.set_cell_factory { DTSCell.new(@get_meta) }
			@type_chooser.items.add_all(*list)
			@known = observable_array_list()
			@type_chooser.selection_model.selected_item = dil.class_type
			update_known
			
      # always show the current team-number induced value
      @host.prompt_text = Java::dashfx.lib.data.InitInfo.new.host
      @name.text_property.bind_bidirectional @dil.path_property
      # TODO: bindings?
      @host.text_property.add_change_listener { re_url }
      @port.text_property.add_change_listener { re_url }
      @path.text_property.add_change_listener { re_url }
      children << OptionDesigner.new(@options, @known)
			re_url
    end
		
		def change_type
			@dil.class_type = @type_chooser.selection_model.selected_item
			re_url
			update_known
		end
		
		def update_known
			@known.clear
			prefx = @get_meta.(@dil.class_type)
			prefx = prefx && prefx.option_names
			@known.add_all(*prefx) if prefx
		end

    def uninit_bindings
      @name.text_property.unbind_bidirectional @dil.path_property
    end

    def re_url
			@urlo = @dil.init_info = Java::dashfx.lib.data.InitInfo.new
      @urlo.host = @host.text
      @urlo.path = @path.text
      @urlo.port = (@port.text.to_i == 0 ? nil : @port.text.to_i)
      @options.each do |op|
        @urlo.set_option(op.name, op.value)
      end
			prefx = @get_meta.(@dil.class_type)
			prefx = prefx && prefx.protocols
			prefx = prefx && prefx[0]
      @url.text = @urlo.url(prefx || "???")
			@on_url_update.(@url.text) if @on_url_update
    end
		
		def on_url &block
			@on_url_update = block
		end

  end

  class OptionDesigner < javafx.scene.layout.GridPane
    include JRubyFX::Controller
    fxml "OptionFragment.fxml"

    def initialize(list, known)
      @list = known
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
	
  class DTSCell < Java::javafx.scene.control.ListCell
    include JRubyFX
		
		def initialize(get_meta)
			super()
			@get_meta = get_meta
		end
		
    def updateItem(item, empty)
      super
      if empty?
        self.graphic = nil
        self.text = nil
			else
				annote = @get_meta.(item)
				self.text = annote.name
				self.tooltip = Tooltip.new("#{annote.description}\n#{item.name}")
				self.graphic = nil
      end
    end
  end
end
