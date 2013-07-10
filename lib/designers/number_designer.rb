
require_relative 'designers'

class SD::Designers::NumberDesigner
  extend SD::Designers
  include JRubyFX

  designer_for Java::double, Java::int, Java::long, Java::float
  designer_for java.lang.Double, java.lang.Float, java.lang.Integer, java.lang.Long, java.lang.Number
  attr_reader :ui

  def initialize
    @ui = SD::DesignerSupport::NumberSpinner.new
  end

  def design(prop)
    ui.value_property.bindBidirectional(prop)
  end
end
