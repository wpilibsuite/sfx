
module SD::DesignerSupport
  class ToolboxItem < Java::javafx::scene::layout::VBox
    include JRubyFX::Controller
    fxml "DesignerToolboxItem.fxml"

    def initialize(obj, dnd_get_id, opts={})
      @obj = obj
      reload_fxml
      @dnd_get_id = dnd_get_id
      @opts = opts if opts != {}
    end

    def reload_fxml
      obj = @obj
      if SD::DesignerSupport::Preferences.toolbox_icons == "Icons&Text"
        children.clear
        load_fxml "DesignerToolboxItemWithText.fxml"
        @label.text = obj.name
      elsif SD::DesignerSupport::Preferences.toolbox_icons == "TextOnly"
        children.clear
        load_fxml "DesignerToolboxItemOnlyText.fxml"
        @label.text = obj.name
      else
        children.clear
        load_fxml "DesignerToolboxItem.fxml"
      end

      Tooltip.install self, tooltip(graphic: vbox!{label(obj.name); label(obj.description)})
      im_is = obj.image_stream
      if im_is
        @img.image = Image.new(im_is)
      end
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
