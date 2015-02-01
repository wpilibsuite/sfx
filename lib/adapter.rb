# Copyright (C) 2015 patrick
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
#      puts "hey hey hey"
#      java.util.concurrent.ForkJoinPool.common_pool.execute do
#        # load all the plugin  stuff
#        
#      # end
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
require 'java'
java_package 'edu.wpi.first.sfx.designer'
class Adapter
  java_signature 'edu.wpi.first.sfx.designer.Adapter main(edu.wpi.first.sfx.designer.DepManager)'
  def self.init(mi)
    return Adapter.new(mi)
  end
  def initialize(mi)
    @mi = mi
    @mi.on "load_jruby_plugins" do |ctr|
      puts "loading plugins"
      begin
      require 'plugins/plugins.rb'
      SD::Plugins.load "built-in", lambda {|url|Java::dashfx.lib.registers.ControlRegister.java_class.resource url}
      puts "done plugins"
      p SD::Plugins.controls
      javafx.application.Platform.run_later do
        mi.toolbox_controls.add_all *SD::Plugins.controls
        ctr.complete(nil)
      end
      rescue Exception
        p $!
        puts $!.backtrace
      rescue java.lang.Throwable
        p $!
        puts $!.print_stack_trace
      end
    end
    @mi.complete("base_jruby_loaded", self)
  end
end