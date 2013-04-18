require 'rubygems'
require 'jrubyfx'
require 'SDLib.jar'
require 'SDInterfaces.jar'

module SD
  class App < JRubyFX::Application
    def start(stage)
      with(stage, :title => "Loading SmartDashboard")
      SD::Designer.load_into stage
      stage.show
    end
  end
end

require 'designer.rb'

SD::App.launch