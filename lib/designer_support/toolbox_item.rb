
module SD::DesignerSupport
  class ToolboxItem < Java::javafx::scene::layout::VBox
    include JRubyFX::Controller
    fxml_root "../res/DesignerToolboxItem.fxml"

    def initialize(obj, dnd_get_id)
      @label.text = obj.to_s
      @obj = obj
      @dnd_get_id = dnd_get_id
      @label.setTooltip tooltip(obj.to_s)
    end

    def dnd_get_id
      @dnd_get_id.call @obj
    end

    def label
      @textBox.text
    end

    def label=(v)
      @textBox.text = v
    end

    def begin_drag(event)
        db = startDragAndDrop(TransferMode::COPY);

        content = ClipboardContent.new
        content.putString(dnd_get_id.to_s);
        db.setContent(content);

        event.consume();
    end
  end
end
