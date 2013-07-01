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

module SD
  module DesignerSupport
    ##
    # PlaceholderFixer is used to close holes in nested FXML controls by replacing the Placeholder class with the needed control
    class PlaceholderFixer
      include JRubyFX
      def initialize(*what_to_replace)
        @replace = what_to_replace
      end

      def fix(root)
        Hash[@replace.map do |itm|
          pholder = instance_variable_get("@#{itm}")
          # set all the properties
          new_ctl = with(SD::Plugins::ControlInfo.find(pholder.control_path).new, YAML.load("{#{pholder.prop_list}}"))
          root.add_control new_ctl
          pholder.replace new_ctl.ui
          [itm, new_ctl]
        end]
      end
    end
  end
end
