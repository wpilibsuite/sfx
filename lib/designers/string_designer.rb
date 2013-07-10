
require_relative 'designers'


class SD::Designers::StringDesigner
  extend SD::Designers
  include JRubyFX

  designer_for java.lang.String
  attr_reader :ui

  def initialize
    @ui = TextField.new
  end

	def design(prop)
		ui.textProperty().bindBidirectional(prop);
  end
end