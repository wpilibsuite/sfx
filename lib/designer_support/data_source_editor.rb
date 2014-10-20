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

require 'java'
require 'jrubyfx'
require 'data_source_selector'

$DEBUG_IT_FXML = true
fxml_root File.join(File.dirname(__FILE__), "../res"), "res"

module SD
  class App < JRubyFX::Application
    def start(stage)
			
			points = observable_array_list()
			bdi = BindableDilItem.new
			bdi.name = "whoosh"
			bdi.path = "/ding/a/ling"
			points << bdi
			bdi = BindableDilItem.new
			bdi.name = "whoosh2"
			bdi.path = "/"
			points << bdi
      with(stage, :title => "SmartDashboard") do
        #layout_scene(fill: :pink) do
          
        #end
				fxml SD::DataSourceSelector, initialize: [points]
        #fxml SD::Designer
        #icons.add image(resource_url(:images, "16-fxicon.png").to_s)
        #icons.add image(resource_url(:images, "32-fxicon.png").to_s)
        #fxml SD::URLDesigner
        show
      end
    end
		
	end

  class BindableDilItem
    include JRubyFX
    fxml_accessor :name
		fxml_accessor :path
    fxml_accessor :class_type, SimpleObjectProperty, java.lang.Class
    fxml_accessor :init_info, SimpleObjectProperty, java.lang.Object
		attr_reader :index
    def initialize(base = nil, index = nil)
			@index = index
			return unless base
      self.name = base.name
      self.path = base.path
      self.init_info = base.init_info
      self.class_type = base.class_type
    end
  end
	# required for java lookup via prop value factory
	BindableDilItem.become_java!
	
  class DataSourceFragDesigner < javafx.scene.layout.VBox
    include JRubyFX::Controller
    fxml "DataSourceFragment.fxml"
		
		def initialize
			# TODO: this must be present. Why?
		end
		
		def selection_model
			@path_list.selection_model
		end
		
		def points=(points)
			@points = points
			@path_list.items = @points
			@path_list.cell_factory = lambda do |x|
				DSSCombo.new(@points)
			end
		end

    def add_pair
      @points << BindableDilItem.new
    end
  end
	
  class DSSCombo < Java::javafx.scene.control.ListCell
    include JRubyFX
		
		def initialize(pts)
			super()
			@points = pts
			# TODO: delete button?
			@btn = button("x", textFill: javafx.scene.paint.Color::RED) # TODO: red
			@btn.set_on_action do
				list_view.items.remove index unless empty?
			end
			self.content_display = javafx.scene.control.ContentDisplay::RIGHT
			# TODO: proper layout
		end
		
    def updateItem(item, empty)
      super
      if empty?
        self.graphic = nil
        self.text = nil
			else
				self.text = "#{item.path} - #{item.name}"
				self.graphic = @btn
      end
    end
  end
	
	
	# MenuItem Adapter for DataBuilder
  class DSSMenuItem < Java::JavafxSceneControl::MenuItem
    def initialize(db, &on_action)
      super()
      self.text = db.name
      @db = db
      on_action {|e| on_action.call(db, e)}
    end
  end

	##
	# This is used for displaying all the possible new data source types in the
	# Drop down menu
  class DataBuilder
    def initialize(e)
      @rclass = e.ruby_class
      @annote = e.annotation(Java::dashfx.lib.controls.DesignableData.java_class)
    end
    def new
      SD::Utils::Url.new("New #{name}", @rclass, nil, nil, "/")
    end
    def name
      @annote.name
    end
    def description
      @annote.description
    end
    def to_s
      @annote.to_s
    end
  end
	
end

SD::App.launch
#            <TextField fx:id="root_url" editable="false" minWidth="30.0" prefColumnCount="1" prefWidth="30.0" text="/" GridPane.columnIndex="0" GridPane.rowIndex="0" />
#            <ComboBox fx:id="root_source" editable="false" maxWidth="1.7976931348623157E308" promptText="None" GridPane.columnIndex="1" GridPane.halignment="LEFT" GridPane.hgrow="ALWAYS" GridPane.rowIndex="0">
#              <items>
#                <FXCollections fx:factory="observableArrayList">
#                  <String fx:value="None" />
#                </FXCollections>
#              </items>
#            </ComboBox>

