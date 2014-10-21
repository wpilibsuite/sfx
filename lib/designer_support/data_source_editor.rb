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

require 'sfxlib.jar'
require 'java'
require 'jrubyfx'
require 'data_source_selector'
$LOAD_PATH << "#{Dir.home}/sunspotfrcsdk/desktop-lib/"
require 'sfxmeta.jar'
require "networktables-desktop.jar"


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
		java_import 'dashfx.lib.data.InitInfo'
		
    def initialize(base = nil, index = nil)
			@index = index
			if base
				self.name = base.name
				self.path = base.path
				self.init_info = base.init_info
				self.class_type = base.class_type
			else
				self.name = ""
				self.path = ""
				self.init_info = InitInfo.new
			end
    end
  end
	# required for java lookup via prop value factory
	BindableDilItem.become_java!
	
  class DataSourceFragDesigner < javafx.scene.layout.VBox
    include JRubyFX::Controller
    fxml "DataSourceFragment.fxml"
		
		def initialize
			# TODO: initialize must be present. Why?
			
			# this avoids a bug in jfx7
			@hack_update = SimpleStringProperty.new
		end
		
		def selection_model
			@path_list.selection_model
		end
		
		def points=(points)
			@points = points
			@path_list.items = @points
			@path_list.cell_factory = lambda do |x|
				DSSCombo.new(@points, @hack_update)
			end
		end

    def add_pair
      @points << BindableDilItem.new
    end
		
		def hack_update_all(url)
			@hack_update.value = url
		end
  end
	
  class DSSCombo < Java::javafx.scene.control.ListCell
    include JRubyFX
		
		def initialize(pts, updater)
			super()
			@points = pts
			(@updater = updater).add_change_listener{ updateItem(item, empty?)}
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
				prefx = item.class_type && item.class_type.annotation(Java::dashfx.lib.controls.DesignableData.java_class)
				prefx = prefx && prefx.protocols
				prefx = prefx && prefx[0]
				self.text = "#{item.path} - #{item.init_info.url(prefx || "???")}"
				self.graphic = @btn
      end
    end
  end
end

SD::App.launch

