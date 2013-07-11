
require_relative 'designers'

class SD::Designers::ColorDesigner
  extend SD::Designers
  include JRubyFX

  designer_for Java::javafx.scene.paint.Color
  attr_reader :ui

  def initialize
    @ui = ColorPicker.new
  end

	def design(prop)
		ui.valueProperty().bindBidirectional(prop.property)
  end
end