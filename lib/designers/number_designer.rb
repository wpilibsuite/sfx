
require_relative 'designers'

class SD::Designers::NumberDesigner
  extend SD::Designers
  include JRubyFX

  designer_for Java::double, Java::int, Java::long, Java::float
  designer_for java.lang.Double, java.lang.Float, java.lang.Integer, java.lang.Long, java.lang.Number
  attr_reader :ui

  def initialize
    @qui = @ui = SD::DesignerSupport::NumberSpinner.new(nil, nil, nil, false) # default way
  end

  def design(prop)
    if annote = prop.method.annotation(Java::dashfx.lib.controls.Range.java_class)
      min = annote.minValue
      if min.nan?
        min = unless annote.minProp.empty?
          min = prop.find(annote.minProp)
          min && min.property
        end
      end
      max = annote.maxValue
      if max.nan?
        max = unless annote.maxProp.empty?
          max = prop.find(annote.maxProp)
          max && max.property
        end
      end
      if max && min
        @qui = Slider.new
        @ui = BorderPane.new
        try_bind(@qui.max_property, max)
        try_bind(@qui.min_property, min)
        @ui.center = @qui
        lbl = SD::DesignerSupport::NumberSpinner.new(min, nil, max, false) # default way
        lbl.value_property.bindBidirectional(prop.property)
        lbl.max_width = lbl.pref_width = 50
        lbl.show_buttons = false
        @ui.right = lbl
      else
        @qui = @ui = SD::DesignerSupport::NumberSpinner.new(min, nil, max, false) # default way
      end
    end
    @qui.value_property.bindBidirectional(prop.property)
  end

  def try_bind(prop, p_or_val)
    if p_or_val.is_a? ObservableValue
      prop.bind(p_or_val)
    else
      prop.value = p_or_val
    end
  end
end
