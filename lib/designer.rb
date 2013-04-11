require 'jrubyfx'
require 'designer_support/toolbox_item'
require 'designer_support/overlay_control'

class SD::Designer
  include JRubyFX::Controller

  fxml_root "res/SFX.fxml"

  def initialize
    # best to catch missing stuff now
    @toolbox= @TooboxTabs
    puts "Going to find addtab...."
    p @testBorderPane
    p @accord
    p @x2
    p @x3
    p @spaine
    p @Content
    @add_tab = @AddTab
    @toolbox_group = {:standard => @STDToolboxFlow}
    p @add_tab, "is addtab", @toolbox
    @add_tab.id = "AddTab" # TODO: hack. FIXME
    puts @add_tab
    puts @toolbox
    #p find!("#AddTab")
    @root = @GridPane
    @canvas = @canvas
    @savedSelection = 1
    @selSem = false
    (@toolbox.tabs.length - 1).times { |i|
      tb = @toolbox.tabs[i+1] # don't want 1st tab
      tb.set_on_selection_changed do |e|
        if tb.selected
          @savedSelection = i + 1
          puts "Changed selection to #{@savedSelection}"
        end
      end }
    @toolbox.set_on_mouse_clicked do |e|
      q = e.target
      while q
        # TODO: this should actually be much simpler comparison
        if q.to_s.include? "TabPaneSkin$TabHeaderSkin" and q.parent and not q.parent.to_s.include? "TabPaneSkin$TabHeaderSkin"
          puts "checking ids and status"
          p q.id, @add_tab.id, @toolbox.get_translate_x
          if q.id == "AddTab" or @toolbox.get_translate_x == 36.0
            v = [300, 36]
            if @toolbox.get_translate_x == 36.0
              v.reverse!
              if q.id == "AddTab"
                @toolbox.selection_model.clear_and_select @savedSelection
              end
            elsif q.id == "AddTab"
              @toolbox.selection_model.select_first
            end
            with(@toolbox) do |tbx|
              timeline do
                animate tbx.translateXProperty, 0.sec => 500.ms, v[0] => v[1]
              end.play
            end
            break
          end
        end
        q = q.parent
      end
    end
    #  onDragOver="#drag_over" onDragDrop="#drag_drop
    # TODO: HACK
    #      @canvas.set_on_drag_over {|e| drag_over(e)}
    #      @canvas.set_on_drag_drop {|e| drag_drop(e)}

    parts = find_toolbox_parts
    parts.each do |key, data|
      data.each{|i| @toolbox_group[key].children.add SD::DesignerSupport::ToolboxItem.new(i)}

    end

    #DEMO

    add_designable_control(button("Hey-yo!"))
  end

  def find_toolbox_parts
    {:standard => %W[Graph PieChart Speedometer Label Solenoid DigitalSwitch Image Camera Motor Gyro]}
  end

  def add_designable_control(control, location=[nil, nil])
    designer = SD::DesignerSupport::Overlay.new(control)
    @canvas.children.add designer
  end

  def drag_over(event)
    if event.gesture_source != self && event.dragboard.hasString
      event.acceptTransferModes(TransferMode::COPY)
    end
    event.consume();
  end

  def drag_drop(event)
    db = event.dragboard
    event.setDropCompleted(
      if db.hasString
        add_designable_control(button db.string)
        with(@toolbox) do |tbx|
          timeline do
            animate tbx.translateXProperty, 0.sec => 500.ms, 300.0 => 36.0
          end.play
        end
        true
      else
        false
      end)

    event.consume()
  end
end