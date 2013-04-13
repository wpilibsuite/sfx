
module SD::DesignerSupport
  class PropertiesPopup < Java::javafx::stage::Popup
    def initialize
      super()
      content.add(PropertiesPane.new)
    end
  end
  class PropertiesPane < Java::javafx::scene::layout::BorderPane
    include JRubyFX::Controller
    fxml_root "../res/PropertiesPopup.fxml"

    def initialize(label="Unknown")
#      @label.text = label
#      @label.setTooltip tooltip(label)
    end

#    def label
#      @textBox.text
#    end
#
#    def label=(v)
#      @textBox.text = v
#    end
#
#    def begin_drag(event)
#        db = startDragAndDrop(TransferMode::COPY);
#
#        content = ClipboardContent.new
#        content.putString(@label.text);
#        db.setContent(content);
#
#        event.consume();
#    end
  end
end
