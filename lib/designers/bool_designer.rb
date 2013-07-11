
require_relative 'designers'


class SD::Designers::BoolDesigner
  extend SD::Designers
  include JRubyFX

  designer_for java.lang.Boolean, Java::boolean
  attr_reader :ui

  def initialize
    @ui = CheckBox.new
  end

	def design(prop)
		ui.selectedProperty().bindBidirectional(prop.property)
  end
end