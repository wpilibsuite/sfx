
module SD::DesignerSupport
  class ToolboxItem < Java::javafx::scene::layout::VBox
    include JRubyFX::Controller
    fxml "DesignerToolboxItem.fxml"

    def initialize(obj, dnd_get_id, opts={})
      @label.text = obj["Name"]
      @obj = obj
      @dnd_get_id = dnd_get_id
      @label.setTooltip tooltip(obj["Description"])
      oi = obj["Image"]
      im_is = obj["ClassLoader"].resource_as_stream(oi) if oi and oi.length > 0
      if im_is
        @img.image = Image.new(im_is)
      end
      @opts = opts if opts != {}
    end

    def dnd_get_id
      @dnd_get_id.call @obj, @opts
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
