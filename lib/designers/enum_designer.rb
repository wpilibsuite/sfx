

require_relative 'designers'

class SD::Designers::EnumDesigner
  extend SD::Designers
  include JRubyFX

  designer_for java.lang.Enum
  attr_reader :ui

  def initialize
    @ui = ComboBox.new
  end

  def enum=(x)
    ui.items = FXCollections.observableArrayList(x.enum_constants)
    ui.selection_mode.selectedItemProperty().add_change_listener do |new|
      if @lprop && (@lprop.value == nil || @lprop.value != new)
        @lprop.value = new
      end
    end
  end

  def design(prop)
    @lprop = prop
    ui.getSelectionModel().select(prop.value)
    prop.add_change_listener do |new|
      ui.selection_model.select new
    end
  end
end