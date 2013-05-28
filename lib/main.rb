require 'jrubyfx'
$LOAD_PATH << "."
require 'sfxlib.jar'
require 'sfxmeta.jar'
require "#{ENV["HOME"]}/sunspotfrcsdk/desktop-lib/networktables-desktop.jar" # TODO: file.join
fxml_root File.join(File.dirname(__FILE__), "res"), "res"

module SD
  class App < JRubyFX::Application
    def start(stage)
      with(stage, :title => "SmartDashboard") do
        fxml SD::Designer
        icons.add image("file://" + File.join(File.dirname(__FILE__), "res", "icon.png"))
        show
      end
    end
  end
end

require 'designer'

SD::App.launch
