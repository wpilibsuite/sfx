
module SD::DesignerSupport
  class ToolboxItem < Java::javafx::scene::layout::VBox
    include JRubyFX::Controller
    fxml_root "../res/DesignerToolboxItem.fxml"

    def initialize(label="Unknown")
      @label.text = label
      @label.setTooltip tooltip(label)
    end

    def label
      @textBox.text
    end

    def label=(v)
      @textBox.text = v
    end
  end
end
