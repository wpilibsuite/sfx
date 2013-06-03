require 'jrubyfx'
require 'designer_support/toolbox_item'
require 'designer_support/overlay_control'
require 'designer_support/properties_popup'
require 'designer_support/aa_tree_cell'
require 'designer_support/toolbox_popup'
require 'designer_support/pref_types'
require 'designer_support/placement_map'
require 'designer_support/aa_filter'
require 'playback'
require 'data_source_selector'
require 'settings_dialog'
require 'yaml'

class SD::Designer
  include JRubyFX::Controller
  java_import 'dashfx.lib.data.DataInitDescriptor'
  java_import 'dashfx.lib.data.InitInfo'
  java_import 'dashfx.lib.registers.ControlRegister'

  fxml "SFX.fxml"

  def initialize
    # best to catch missing stuff now
    @toolbox= @TooboxTabs
    @selected_items = []
    @dnd_ids = []
    @dnd_opts = {}
    @add_tab = @AddTab
    @toolbox_group = {:standard => @STDToolboxFlow}
    @add_tab.id = "AddTab" # TODO: hack. FIXME
    @root = @GridPane
    @canvas = @canvas
    @savedSelection = 1
    @preparsed = 0
    @ui2pmap = {}
    @selSem = false
    @mode = :design
    @toolbox_status = :hidden
    @aa_tree = @AATreeview
    @data_core_sublist = []
    @aa_tree.root = tree_item("/")

    # Load preferences
    @prefs = java.util.prefs.Preferences.user_node_for_package(InitInfo.java_class)
    # get the AutoAdd Filter
    @aa_filter = SD::DesignerSupport::AAFilter
    @aa_filter.parse(@prefs)

    # Create our data core. TODO: use preferences to configure it.
    @data_core = Java::dashfx.lib.data.DataCore.new()
    # when the data core finds about new names, let us know!
    @data_core.known_names.add_change_listener do |change|
      change.next # change is an "iterator" of stuff, so use next to get the added list
      sublist = []
      change.added_sub_list.each do |new_name|
        add_known new_name
        # check to see if we should auto-add this
        if @aa_filter.filter(new_name, @data_core.known_names.get)
          sublist << new_name
          @data_core_sublist << new_name
        end
      end
      # TODO: total race condition
      if sublist.length > 0 && @data_core_sublist.length == sublist.length
        Thread.new do
          sleep 0.07
          run_later do
            aa_add_some(*@data_core_sublist)
            @data_core_sublist = []
          end
        end
      end
    end
    # When we hit the tabs, modify the selected index
    (@toolbox.tabs.length - 1).times { |i|
      tb = @toolbox.tabs[i+1] # don't want 1st tab
      tb.set_on_selection_changed do |e|
        if tb.selected
          @savedSelection = i + 1
        end
      end }
    # when we click the tab buttons, pop it out and select the above saved index
    @toolbox.set_on_mouse_clicked do |e|
      q = e.target
      # find if the target chain includes a tab
      while q
        # TODO: this should actually be much simpler comparison
        if q.to_s.include? "TabPaneSkin$TabHeaderSkin" and q.parent and not q.parent.to_s.include? "TabPaneSkin$TabHeaderSkin"
          # TODO: clean this up a bit.
          if q.id == "AddTab" or @toolbox.get_translate_x == 36.0
            mode = :hide
            if @toolbox.get_translate_x == 36.0
              mode = :show
              if q.id == "AddTab"
                @toolbox.selection_model.clear_and_select @savedSelection
              end
            elsif q.id == "AddTab"
              @toolbox.selection_model.select_first
            end
            if mode == :hide # TODO: clean this up
              hide_toolbox
            else
              show_toolbox
            end
            break
          end
        end
        q = q.parent
      end
    end

    # get all toolbox bits and add them to the ui toolbox
    parts = find_toolbox_parts
    parts.each do |key, data|
      data.each{|i| @toolbox_group[key].children.add SD::DesignerSupport::ToolboxItem.new(i, method(:associate_dnd_id))}
    end

    # Set the auto add tree cells
    @aa_tree.set_cell_factory do |q|
      SD::DesignerSupport::AATreeCell.new
    end

    # On shown and on closing handlers
    @stage.set_on_shown do
      self.message = "Ready"
      @stage.title += " : Untitled"
      SD::DesignerSupport::Overlay.preparse_new(3)
    end
    @stage.set_on_close_request do
      @canvas.dispose
    end

    # get the team number
    # if the team number is set in prefs, use it
    ip = if !@prefs.get_boolean("team_number_auto", true) and (1..9001).include? @prefs.get_int("team_number", 0)
      @prefs.get_int("team_number", 0)
    else # otherwise, snag from nics and if we have not set any preferences, save it.
      snag_ip.tap do |x|
        if x && (1..9001).include?(x) && !@prefs.get_boolean("team_number_auto", false) && @prefs.get_boolean("team_number_auto", true) # nothing set
          @prefs.put_boolean("team_number_auto", false)
          @prefs.put_int("team_number", x)
        end
      end
    end
    if ip
      self.message = "Using #{ip == 0 ? "localhost" : ip } as team number"
      InitInfo.team_number = ip
    end

    # assign the root canvas node from preferences
    root = @prefs.get("root_canvas", "Canvas")
    self.root_canvas = parts[:standard].find{|x|x["Name"] == root}[:proc].call

    # set up preferred types
    SD::DesignerSupport::PrefTypes.create_toolbox(parts, @prefs)

    #TODO: use preferences for this. DEMO
    @canvas.mountDataEndpoint(DataInitDescriptor.new(Java::dashfx.lib.data.endpoints.NetworkTables.new, "Default", InitInfo.new, "/"))
    #TODO: use standard plugin arch for this
    @playback = SD::Playback.new(@data_core, @stage)

    # pre-parse one item for speedy adding
    SD::DesignerSupport::Overlay.preparse_new(1)
    # do this now so props are fast to load
    @properties = SD::DesignerSupport::PropertiesPopup.new

    # when we blur, hide the properties window. TODO: property window needs improvements
    @stage.focused_property.add_change_listener do |v, o, new|
      unless new
        @was_showing = @properties.showing?
        @properties.hide
      else
        @properties.show(@stage) if @was_showing
      end
    end
  end

  # iterate over all the interfaces on this computer and find one that matches 10.x.y.z, where x and y < 100
  def snag_ip
    java.net.NetworkInterface.network_interfaces.each do |networkInterface|
      networkInterface.inet_addresses.each do |inet|
        addr = inet.address
        if addr[0] == 10 && addr.length == 4 && addr[1] < 100 && addr[2] < 100 # TODO: will fail for alt 10.4.151.x
          teamn = addr[1] * 100 + addr[2]
          return teamn
        end
      end
    end
  end

  # easy dnd way to send objects. should use actual text or an hash
  def associate_dnd_id(val, opts=nil)
    @dnd_ids << val unless @dnd_ids.include?(val)
    @dnd_opts[val] = opts
    @dnd_ids.index(val)
  end

  # Scrounge around and find everything that should go in the toolbox. TODO: modularize this to use plugins
  def find_toolbox_parts
    unless @found_plugins # cache it as its expensive
      xdesc = YAML::load_stream(ControlRegister.java_class.resource_as_stream("/manifest.yml").to_io)
      #TODO: why is this doubled [[]] ???
      xdesc = xdesc[0]
      # process the built in yaml
      if xdesc["API"] != 0.1
        abort("Built in manifest version is wrong! Something went horrible! expected 0.1 but got #{xdesc["Manifest API"]}")
      end

      # fix up each thing in the data to be proper
      xdesc["Data"].each do |x|
        oi = x["Image"]
        x["ImageStream"] = Proc.new do
          if oi and oi.length > 0
            ControlRegister.java_class.resource_as_stream(oi)
          else
            nil
          end
        end
        x["Types"] = [x["Types"] || x["Supported Types"]].flatten.reject(&:nil?).map{|x|Java::dashfx.lib.data.SmartValueTypes.valueOf(x).mask}
        x[:proc] = Proc.new {
          fx = FxmlLoader.new
          fx.location = ControlRegister.java_class.resource(x["Source"])
          fx.load.tap do |obj|
            x["Defaults"].each do |k, v|
              obj.send(k + "=", v)
            end if x["Defaults"]
          end
        }
      end

      desc = xdesc["Data"]

      # check for the plugins folder
      plugin_yaml = $PLUGIN_DIR
      if Dir.exist? plugin_yaml
        xdesc = YAML::load_file(File.join(plugin_yaml, "manifest.yml"))
        if xdesc["API"] != 0.1
          puts("Built in external manifest version is wrong! expected 0.1 but got #{xdesc["Manifest API"]}")
          xdesc["Data"] = []
        end
        # process the built in yaml
        xdesc["Data"].each do |x|
          oi = x["Image"]
          x["ImageStream"] = Proc.new do
            if oi and oi.length > 0
              java.net.URL.new("file://#{plugin_yaml}#{oi}").open_stream
            else
              nil
            end
          end
          x["Types"] = [x["Types"] || x["Supported Types"]].flatten.reject(&:nil?).map{|x|Java::dashfx.lib.data.SmartValueTypes.valueOf(x).mask}
          x[:proc] = Proc.new {
            fx = FxmlLoader.new
            fx.location = java.net.URL.new("file://#{plugin_yaml}#{x["Source"]}")
            fx.load.tap do |obj|
              x["Defaults"].each do |k, v|
                obj.send(k + "=", v)
              end
            end
          }
        end

        # add build in descriptors to all the descriptors
        desc += xdesc["Data"]
      end

      # Process the java classes with their annotations
      ControlRegister.all.each do |jclass|
        annote = jclass.annotation(Java::dashfx.lib.controls.Designable.java_class)
        oi = annote.image
        cat_annote = jclass.annotation(Java::dashfx.lib.controls.Category.java_class)
        cat_annote = cat_annote.value if cat_annote
        types_annote = jclass.annotation(Java::dashfx.lib.data.SupportedTypes.java_class)
        types_annote =  if types_annote
          types_annote.value.map{|x|x.mask}
        else
          []
        end
        desc << {
          "Name" => annote.value,
          "Description" => annote.description,
          "Image" => annote.image,
          "ImageStream" => Proc.new do
            if oi and oi.length > 0
              jclass.ruby_class.java_class.resource_as_stream(oi)
            else
              nil
            end
          end,
          "Category" => cat_annote,
          "Types" => types_annote,
          proc: Proc.new { jclass.ruby_class.new }
        }
      end
      @toolbox_bits = {:standard => desc}
      @found_plugins = true
    end
    @toolbox_bits
  end

  # called to wrap the control in an overlay and to place in a control
  def add_designable_control(control, x=0, y=0, parent=@canvas, oname=nil)
    designer = SD::DesignerSupport::Overlay.new(control, self, parent, oname)

    # if its designable, add hooks for nested editing to work
    if control.is_a? Java::dashfx.lib.controls.DesignablePane
      designer.set_on_drag_dropped &method(:drag_drop)
      designer.set_on_drag_over &method(:drag_over)
    end
    if x == y && y == nil && parent.appendable?
      parent.children.add(designer)
    else
      # offset to look like its placed correctly at the mouse point. TODO: do we want to place at center?
      x -= 10 if x
      y -= 10 if y
      parent.add_child_at designer,x,y
    end
    # Add it to the map so we can get the controller later if needed from UI tree
    @ui2pmap[control.ui] = control
    self.message = "Added new #{control.java_class.name}"
    designer
  end

  def ui2p(ui)
    @ui2pmap[ui]
  end

  def add_known(item)
    @aa_tree.root.children.add tree_item(item) #TODO: nested
  end

  def drag_over(event)
    if event.gesture_source != self && event.dragboard.hasString
      event.acceptTransferModes(TransferMode::COPY)
    end
    event.consume();
  end

  # whenever we drop something on the canvas, this is called. There are two cases: auto add droppings, or normal droppings
  def drag_drop(event)
    db = event.dragboard
    event.setDropCompleted(
      if db.hasString
        if db.string.start_with? "AutoAdd:"
          id = db.string[8..-1] #strip prefix
          #open a popup and populate it
          tbx_popup = SD::DesignerSupport::ToolboxPopup.new # TODO: cache these items so we don't have to reparse fxml
          find_toolbox_parts.each do |key, data| # TODO: grouping and sorting
            data.reject{|x|x["Category"] == "Grouping"}.each do |i|
              ti = SD::DesignerSupport::ToolboxItem.new(i, method(:associate_dnd_id), :assign_name => id)
              ti.set_on_mouse_clicked do
                drop_add associate_dnd_id(i, :assign_name => id), event.x, event.y, event.source
                @on_mouse.call if @on_mouse # hide it
              end
              tbx_popup.add ti
            end
          end
          # position the popup at the location of the mouse
          tbx_popup.x = event.screen_x
          tbx_popup.y = event.screen_y
          # when we click other places, hide the toolbox
          register_clickoff do
            tbx_popup.hide
          end
          tbx_popup.show @stage
          SD::DesignerSupport::Overlay.preparse_new(1)
        else
          drop_add(db.string.to_i, event.x, event.y, event.source)
        end
        true
      else
        false
      end)

    event.consume()
  end

  # called to add a namable control to the items
  def drop_add(id,x, y, source)
    pare = source == @canvas.ui ? @canvas : source.child
    dnd_obj = @dnd_ids[id]
    obj = dnd_obj[:proc].call # create the object that we are dragging on
    if @dnd_opts[dnd_obj]
      # TODO: check for other options
      obj.name = @dnd_opts[dnd_obj][:assign_name] if obj.respond_to? :name
    end
    add_designable_control obj, x, y, pare, @dnd_ids[id]["Name"]
    hide_toolbox
    @clickoff_fnc.call if @clickoff_fnc
    @on_mouse.call(nil) if @on_mouse
  end

  def morph_child(overlay, event) #TODO: drip drip drip leakage
    tbx_popup = SD::DesignerSupport::ToolboxPopup.new # TODO: cache these items so we don't have to reparse fxml
    find_toolbox_parts.each do |key, data| # TODO: grouping and sorting
      data.reject{|x|x["Category"] == "Grouping"}.each do |i|
        ti = SD::DesignerSupport::ToolboxItem.new(i, method(:associate_dnd_id))
        ti.set_on_mouse_clicked do
          obj = i[:proc].call
          yield(obj, i)
          @ui2pmap[obj.ui] = obj
          self.message = "Added new #{obj.java_class.name}"
          hide_toolbox
          @clickoff_fnc.call if @clickoff_fnc
          @on_mouse.call(nil) if @on_mouse
        end
        tbx_popup.add ti
      end
    end
    # position the popup at the location of the mouse
    tbx_popup.x = overlay.local_to_scene(overlay.bounds_in_local).min_x
    tbx_popup.y = overlay.local_to_scene(overlay.bounds_in_local).min_y
    # when we click other places, hide the toolbox
    register_clickoff do
      tbx_popup.hide
    end
    tbx_popup.show @stage
  end

  # These functions are used to do "clickoffs" aka close a window when you click anywhere
  def register_clickoff(&fnc)
    @clickoff_fnc = fnc
    on_mouse = @on_mouse = Proc.new do |e|
      e.consume if e
      @GridPane.remove_event_filter(MouseEvent::MOUSE_PRESSED,on_mouse)
      fnc.call
      @on_mouse = nil
    end
    @GridPane.add_event_filter(MouseEvent::MOUSE_PRESSED,on_mouse)
  end

  # TODO: somehow merge with above method
  def register_toolbox_clickoff(&fnc)
    @clickoff_tbx = fnc
    on_tmouse = @on_tmouse = Proc.new do |e|
      q = e.nil? ? false : e.target
      while q
        if q == @toolbox
          q = false
        else
          q = q.parent
        end
      end
      if q == nil # no parents found
        @GridPane.remove_event_filter(MouseEvent::MOUSE_PRESSED,on_tmouse)
        @clickoff_tbx.call
        @on_tmouse = nil
      end
    end
    @GridPane.add_event_filter(MouseEvent::MOUSE_PRESSED,on_tmouse)
  end

  def multiple_selected?
    @selected_items.length > 1
  end

  def multi_drag(original)
    @just_dragged = true
    (@selected_items - [original])
  end

  def run
    @mode = :run
    @canvas.children.each do |c|
      c.running = true
    end
    hide_controls
    hide_toolbox
    hide_properties
    @canvas.resume
  end

  def design
    @mode = :design
    @canvas.pause
    @canvas.children.each do |c|
      c.running = false
    end
    show_controls
  end

  def hide_controls
    animate_controls(true)
  end

  def animate_controls(hide)
    mul = hide ? -1 : 1
    nul = hide ? 0 : 1
    # TODO: this should be cleaned up
    lg = @left_gutter
    bg = @bottom_gutter
    tb = @toolbox
    sb = @stop_button
    stg = @stage
    oy = stg.y
    # The properties are read only because of OS issues, so we just create a proxy
    stg_wap = SimpleDoubleProperty.new(stg.width)
    stg_wap.add_change_listener {|ov, old, new| stg.setWidth(new) }
    stg_hap = SimpleDoubleProperty.new(stg.height)
    stg_hap.add_change_listener {|ov, old, new| stg.setHeight(new); stg.y = oy }
    stg_xap = SimpleDoubleProperty.new(stg.x)
    stg_xap.add_change_listener {|ov, old, new| stg.x = new }
    timeline do
      animate lg.prefWidthProperty, 0.ms => 500.ms, (32 - 32 * nul) => (32 * nul)
      animate bg.translateYProperty, 0.ms => 500.ms, (32 * nul) => (32 - 32 * nul)
      animate tb.translateXProperty, 0.ms => 500.ms, (36 - 36 * nul) => (36 * nul)
      animate sb.visibleProperty, 0.ms => 500.ms, (!hide) => hide
      animate stg_wap, 0.ms => 500.ms, stg.width => (stg.width + 32 * mul)
      animate stg_hap, 0.ms => 500.ms, stg.height => (stg.height + 32 * mul)
      animate stg_xap, 0.ms => 500.ms, stg.x => (stg.x - 32 * mul)
    end.play
  end


  def show_controls
    animate_controls(false)
  end

  # set the popup message at the bottom
  def message=(msg)
    @alert_msg.text = msg
    with(@msg_carrier) do |mc|
      timeline do
        animate mc.translateYProperty, 0.sec => [200.ms, 5.sec, 5.2.sec], 30.0 => [0.0, 0.0, 30.0]
      end.play
    end
  end

  def hide_properties
    if @properties
      @properties.hide
    end
  end

  def update_properties
    if @selected_items.length < 1 or @selected_items.find_all { |i| !i.editing_nested }.length != 1
      hide_properties
    else
      @properties.properties = @selected_items[0].properties
      sic = @selected_items[0].child
      name = sic.name if sic.respond_to? :name
      name = @selected_items[0].original_name unless name
      name = sic.java_class.name.split(".").last unless name
      @properties.title = name
      properties_show_around @selected_items[0]
    end
  end

  def properties_draghide
    hide_properties
  end

  def properties_dragshow(elt)
    properties_show_around(elt)
  end

  # display the properties near some element
  def properties_show_around(elt)
    bnds = elt.localToScene(elt.getBoundsInLocal)
    scr_x = @scene.x + @stage.x
    scr_y = @scene.y + @stage.y
    scr = Screen.getScreensForRectangle(scr_x, scr_y, 1, 1)[0]
    loc_x = bnds.max_x + scr_x + 5
    loc_y = bnds.min_y + scr_y
    if scr.bounds.max_x <= loc_x + @properties.width
      loc_x = bnds.min_x + scr_x - 5 - @properties.width
    end
    if scr.bounds.max_y <= loc_y + @properties.height
      loc_y = bnds.max_y + scr_y - @properties.height
    end
    @properties.y = loc_y
    @properties.x = loc_x
    @properties.show(@stage)
  end

  def hide_toolbox
    return if @toolbox_status == :hidden
    @toolbox_status = :hidden
    @clickoff_tbx = Proc.new {|x|}
    @on_tmouse.call if @on_tmouse
    @toolbox.selection_model.select_first
    with(@toolbox) do |tbx|
      timeline do
        animate tbx.translateXProperty, 0.sec => 500.ms, 300.0 => 36.0
      end.play
    end
    @add_tab_icon.image = @add_tab_plus
  end

  def show_toolbox
    return if @toolbox_status == :visible
    @toolbox_status = :visible
    with(@toolbox) do |tbx|
      timeline do
        animate tbx.translateXProperty, 0.sec => 500.ms, 36.0 => 300.0
      end.play
    end
    register_toolbox_clickoff do
      hide_toolbox
    end
    @add_tab_icon.image = @add_tab_close
  end

  def canvas_click(e)
    if @just_dragged
      @just_dragged  = false
      return
    end
    return if @mode != :design
    q = e.target
    new_selections = e.control_down? ? @selected_items : []
    begin
      if q.is_a? SD::DesignerSupport::Overlay
        if e.control_down? and new_selections.include? q
          new_selections -= [q]
        else
          new_selections << q
        end
        break
      end
    end while (q = q.parent) && q != @canvas
    select(*new_selections)
  end

  def select(*items)
    new_selections = items
    (@selected_items + new_selections).each do |si|
      si.selected = new_selections.include? si
    end
    @selected_items = new_selections
    update_properties
  end

  def do_playback_mode
    puts "Playback!"
    @playback.launch
  end

  def delete_selected
    @selected_items.each do |si|
      @canvas.children.remove(si)
    end
    @selected_items = []
    hide_properties
  end

  def canvas_keyup(e)
    if e.code == KeyCode::DELETE
      delete_selected
    end
  end

  def nested_edit(octrl)
    nested_traverse(octrl, lambda { |ctrl|
        ui2p(ctrl.parent).edit_nested(ctrl) do
          exit_nesting(octrl)
        end}) do |x|
      x.disabled = true
    end
  end

  def exit_nesting(octrl)
    octrl.disabled = false
    octrl.exit_nesting
    nested_traverse(octrl, lambda { |ctrl| ui2p(ctrl.parent).exit_nested }) do |x|
      if x.is_a? SD::DesignerSupport::Overlay
        x.disabled = false
        x.exit_nesting
      end
    end
  end

  # helper function for traversing parents when nesting editing
  def nested_traverse(octrl, after, &eachblock)
    return if octrl == @canvas.ui
    ctrl = octrl
    begin
      saved = (ctrl.parent.children.to_a.find_all{|i| i != ctrl})
      saved.each &eachblock
      after.call(ctrl)
      ctrl = ctrl.parent
    end while ctrl != @canvas.ui
  end

  # Settings for the canvas TODO: add other canvas properties
  def show_data_sources
    data_core = @data_core
    stg = @stage
    stage(init_style: :utility, init_modality: :app, title: "Data Source Selector") do
      init_owner stg
      center_on_screen
      fxml SD::DataSourceSelector, :initialize => [data_core]
    end.show_and_wait
  end

  # Add all known controls
  def aa_add_all
    # for each of the items in the tree view (TODO: NOT A TREE VIEW), add it as the pref type
    aa_add_some(*@aa_tree.root.children.map{|x| x.value})
  end

  def aa_add_some(*names)
    # get a placement map if we need one (Aka we cant just append the item)
    fmap = if @canvas.appendable?
      nil
    else
      SD::DesignerSupport::PlacementMap.new(10, @canvas.ui.width, @canvas.ui.height).tap do |pm|
        # add all the current children to the occupancy map
        @canvas.children.each do |child|
          bip = child.bounds_in_parent
          pm.occupy_rectangle(bip.min_x, bip.max_x, bip.min_y, bip.max_y)
        end
      end
    end

    objs = names.map do |ctrl_name|
      ctrl = @data_core.get_observable(ctrl_name)
      new_objd = SD::DesignerSupport::PrefTypes.for(ctrl.type)
      new_obj = new_objd[:proc].call
      if new_obj
        x = y = @canvas.appendable? ? nil : 0.0
        add_designable_control with(new_obj, name: ctrl.name), x, y, @canvas, new_objd["Name"]
      else
        puts "Warning: no default control for #{ctrl.type.mask}"
        nil
      end
    end
    hide_toolbox
    # if we need to position stuff ourselves, wait a bit so layout passes happen
    unless @canvas.appendable?
      Thread.new do
        sleep 0.05
        run_later do
          objs.each do |itm|
            next unless itm
            @canvas.ui.layout
            # do a brute force search on spaces that fit
            x, y = catch :done do
              0.step(@canvas.ui.width, 10) do |x|
                0.step(@canvas.ui.height, 10) do |y|
                  throw(:done, [x,y]) unless fmap.rect_occupied?(x, x+itm.width, y, y+itm.height)
                end
              end
            end
            # once we find a location, place the control at that location and mask it off in the map
            itm.layout_x = x
            itm.layout_y = y
            bip = itm.bounds_in_parent
            fmap.occupy_rectangle(bip.min_x, bip.max_x, bip.min_y, bip.max_y)
          end
        end
      end
    end
  end

  def aa_add_new
    @aa_filter.always_add = !@aa_filter.always_add
  end

  # edit the smart dashboard settings
  def edit_settings
    hide_properties
    stg = @stage
    prefs = @prefs
    this = self
    stage(init_style: :utility, init_modality: :app, title: "SmartDashboard Settings") do
      init_owner stg
      fxml SD::SettingsDialog, :initialize => [prefs, this]
      show_and_wait
    end
  end

  # Assign the designer surface and set up handlers
  def root_canvas=(cvs)
    if @canvas
      childs = @canvas.children.to_a
      @canvas.children.clear
      cvs.children.add_all(childs)
    end
    cvs.registered(@data_core)
    @BorderPane.center = cvs.ui
    @canvas = cvs
    @ui2pmap[cvs.ui] = cvs
    cvs.ui.style = "" # TODO: hack
    cvs.ui.setOnDragDropped &method(:drag_drop)
    cvs.ui.setOnDragOver &method(:drag_over)
    cvs.ui.setOnMouseReleased &method(:canvas_click)
  end
end
