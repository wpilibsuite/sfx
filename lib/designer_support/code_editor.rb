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
    class CodeEditor
      include JRubyFX::Controller
      fxml "CodeEditor.fxml"

      def initialize(blk, code)
        @blk = blk
        self.code = code
      end

      def code
        @code_area.text
      end

      def code=(value)
        @code_area.text = value
      end

      def ok
        @blk.call(code)
        @stage.hide
      end

      def cancel
        @blk.call(false)
        @stage.hide
      end


      def self.show_and_wait(stg, code)
        res = nil
        blk = lambda{|result|res = result}
        stage(init_style: :utility, init_modality: :app, title: "Code Editor") do
          init_owner stg
          fxml SD::DesignerSupport::CodeEditor, :initialize => [blk, code]
          show_and_wait
        end
        res
      end
    end
  end
end
