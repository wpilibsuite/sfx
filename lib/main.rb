require 'jrubyfx'
$LOAD_PATH << "."
require 'SDLib.jar'
require 'SDInterfaces.jar'
require "#{ENV["HOME"]}/sunspotfrcsdk/desktop-lib/networktables-desktop.jar" # TODO: file.join
fxml_root File.join(File.dirname(__FILE__), "res"), "res"

module SD
  class App < JRubyFX::Application
    def start(stage)
      with(stage, :title => "SmartDashboard")
      puts "Begin loading..."
      SD::Designer.load_into stage
      stage.icons.add image("file://" + File.join(File.dirname(__FILE__), "res", "icon.png"))
      stage.show
    end
  end
end

require 'designer.rb'

SD::App.launch