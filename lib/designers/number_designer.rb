
require_relative 'designers'

class SD::Designers::NumberDesigner
  extend SD::Designers
  include JRubyFX

  designer_for Java::double, Java::int, Java::long, Java::float
  designer_for java.lang.Double, java.lang.Float, java.lang.Integer, java.lang.Long, java.lang.Number
  attr_reader :ui

  def initialize
    @slider = Slider.new
    @ui = BorderPane.new

    @slider.max = 40
    @slider.min = -40
    @ui.center = @slider
    lbl = Label.new
    lbl.textProperty().bind(@slider.valueProperty().asString("%.2f"));
    @ui.right = lbl
  end

  #FIXME: TODO: use normal spinner
  def design(prop)
    @slider.valueProperty().bindBidirectional(prop);
  end
end