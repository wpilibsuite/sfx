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
    class SaveQuestion
      include JRubyFX::Controller
      fxml "SaveQuestion.fxml"
      attr_reader :res

      def initialize(cb)
        @res = cb
      end

      def save
        done :save
      end
      def dont_save
        done :dont_save
      end
      def cancel
        done :cancel
      end

      def done(res)
        @res.call res
        @stage.hide
      end

      def self.ask(stage)
        res = :cancel
        stage(init_style: :utility, init_modality: :app, title: "Unsaved Changes") do
          init_owner stage
          fxml SD::DesignerSupport::SaveQuestion, :initialize => [lambda{|x|res=x}]
          show_and_wait
        end
        return res
      end
    end
  end
end
