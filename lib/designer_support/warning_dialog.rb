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
  module DesignerSupport
    class WarningDialog
      include JRubyFX::Controller
      fxml "WarningDialog.fxml"
      
      def initialize(title, desc)
        @messageLabel.text = title
        @detailsLabel.text = desc
      end

      def hide
        @stage.hide
      end
      
      def self.show(stage, title, desc)
        stage(init_style: :utility, init_modality: :app, title: "Warning") do
          init_owner stage
          fxml SD::DesignerSupport::WarningDialog, :initialize => [title, desc]
          show_and_wait
        end
      end
    end
  end
end
