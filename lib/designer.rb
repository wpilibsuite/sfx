require 'thread'

class SD::Designer
  include JRubyFX::Controller
  java_import 'dashfx.lib.data.DataInitDescriptor'
  java_import 'dashfx.lib.data.InitInfo'
  java_import 'dashfx.lib.registers.ControlRegister'

  property_accessor :running, :vc_index
  attr_accessor :view_controllers

  fxml "SFX.fxml"

  @@singleton = nil

  def initialize
    raise "Multiple designers created!" if @@singleton
    @@singleton = self
    # best to catch missing stuff now
    @toolbox= @left_gutter
    @selected_items = []
    @dnd_ids = []
    @dnd_opts = {}
    @add_tab = @AddTab
    @toolbox_group = {}
    @root = @GridPane
    @savedSelection = 1
    @preparsed = 0
    @ui2pmap = {}
    @wingman = {}
    @selSem = false
    @mode = :design
    @toolbox_status = :hidden
    @aa_tree = @AATreeview
    @data_core_sublist = []
    @aa_tree_list = []
    @aa_tree.root = tree_item("/")
    @aa_tree_hash = {"/" => @aa_tree.root, "." => @aa_tree.root}
    @layout_managers = {}
    @view_controllers = FXCollections.observableArrayList
    @aa_name_trees = {}
    @aa_name_trees_threads = {}
    @running = simple_boolean_property(self, "running", false)
    @aa_ignores = []
    @vc_focus = []
    @vc_index = simple_integer_property(self, "vc_index", 0)
    @nested_list = {}

    @overlay_pod.min_width_property.bind(@spain.width_property.subtract(2.0))
    @overlay_pod.min_height_property.bind(@spain.height_property.subtract(2.0))


    # load the custom regexer
    @aa_regexer.text_property.add_change_listener do |ov, ol, new|
      begin
        regx = Regexp.new(new, "i")
        # @aa_filter.regex = regx # TODO: fix
        # filter the list
        @aa_tree_list.each do |child|
          child[:fout] = child[:value].match(regx) == nil
        end
        # clear all the children
        @aa_tree.root.children.clear
        @aa_tree_hash.values.each do |v|
          v.children.clear
        end
        # add anything that matches
        @aa_tree_list.find_all{|x|!x[:fout]}.each{|x|add_known(x[:value])}
        @aa_regexer.style = "-fx-border-color: green;"
        @aa_regex_message.text = "Valid regex"
      rescue Exception => e
        @aa_regex_message.text = e.message
        @aa_regexer.style = "-fx-border-color: red;"
      end
    end
    aa_hide_regex_panel() # it shows by default

    # On shown and on closing handlers
    @stage.set_on_shown { on_shown }
  end

  def self.require_thread
    Thread.new do
      @@requires = [Mutex.new, Mutex.new, Mutex.new]
      @@requires[0].synchronize do
        require 'yaml'
        q = Dir["#{File.dirname(__FILE__)}/plugins/*.rb"]
        q.each {|file| require file}
        require 'rubygems/package'
      end
      while @@singleton == nil
        sleep 0.01
      end
      @@singleton.init_stage_1
    end
  end

  def on_shown
    require 'designer_support/aa_tree_cell'

    # Set the auto add tree cells
    @aa_tree.set_cell_factory do |q|
      SD::DesignerSupport::AATreeCell.new
    end

    require 'designer_support/preferences'
    # Create our data core. TODO: use preferences to configure it.
    @data_core = Java::dashfx.lib.data.DataCore.new()
    # when the data core finds about new names, let us know!
    @data_core.known_names.add_change_listener do |change|
      change.next # change is an "iterator" of stuff, so use next to get the added list
      change.added_sub_list.each do |new_name|
        next if @aa_ignores.include? new_name
        add_known new_name
        @view_controllers.each do |vc|
          if tmp = vc.should_add?(new_name, @data_core.known_names.get)
            bits = new_name.split('/').reject(&:empty?)
            mutex, thread, time_func = @aa_name_trees_threads[vc]
            mutex.synchronize do
              root = @aa_name_trees[vc]
              namepart = ""
              bits.each do |namebit|
                namepart += "/" # Can't use << here or we modify the strings that are already in the treeview
                namepart << namebit
                child = root.children[namebit]
                unless child
                  child = root.children[namebit] = SD::DesignerSupport::AANameTree.new(namepart, root, time_func)
                end
                root = child
              end
            end
            thread.run
          end
        end
      end
    end
    #    now! "shown"
    self.message = "Loading..."
  end

  def init_stage_1
    # Load preferences

    require 'designer_support/preferences' # might not be loaded yet
    @prefs = SD::DesignerSupport::Preferences

    # get the team number
    # if the team number is set in prefs, use it
    ip = if !@prefs.team_number_auto and (1..9001).include? @prefs.team_number
      @prefs.team_number || 0
    else # otherwise, snag from nics and if we have not set any preferences, save it.
      snag_ip.tap do |x|
        if x and (1..9001).include? x and not @prefs.has_key? :team_number_auto
          @prefs.team_number_auto = false
          @prefs.team_number = x
        end
      end
    end
    if ip
      InitInfo.team_number = ip
    end
    @@requires[1].synchronize do
      # get all toolbox bits and add them to the ui toolbox
      run_later do
        pts = find_toolbox_parts
        #load recent files
        build_open_menu
        @@requires[1].synchronize do
          pts.each do |key, data|
            data.sort{|a, b| a.name <=> b.name }.each{|i| @toolbox_group[key].children.add SD::DesignerSupport::ToolboxItem.new(i, method(:associate_dnd_id))}
          end
        end


        SD::DesignerSupport::AANameTree.observable = ->(name){@data_core.get_observable name}

        # do this now so props are fast to load
        @properties = SD::DesignerSupport::PropertiesPopup.new
        @locked_props = false

        # when we blur, hide the properties window. TODO: property window needs improvements
        @stage.focused_property.add_change_listener do |v, o, new|
          unless @locked_props
            unless new
              @was_showing = @properties.showing?
              @properties.hide
            else
              @properties.show(@stage) if @was_showing
            end
          end
        end

        @stage.on_close_request &method(:on_close_request)

        # Add known tab and any plugin tabs
        main_vc = SD::Windowing::DefaultViewController.new
        main_vc.on_focus_request do |focus|
          tab_auto_focus(main_vc, focus)
        end
        main_tab = add_tab(main_vc)
        SD::Plugins.view_controllers.find_all{|x|x.default > 0}.each do |x|
          vc = x.new
          vc.on_focus_request do |focus|
            tab_auto_focus(vc, focus)
          end
          add_tab(vc)
        end
        tab_select(main_tab)


        #TODO: use preferences for this. DEMO.
        @data_core.mountDataEndpoint(DataInitDescriptor.new(Java::dashfx.lib.data.endpoints.NetworkTables.new, "Default", InitInfo.new, "/"))

        require 'playback'
        #TODO: use standard plugin arch for this
        @playback = SD::Playback.new(@data_core, @stage)

        self.message = "Ready"
        #        now! "finished"
      end
      require 'designer_support/toolbox_item'
      require 'designer_support/properties_popup'
      require 'designer_support/aa_name_tree'
      require "windowing/default_view_controller"
    end
    require 'designer_support/properties_popup'
    require 'ostruct'
    %W[designer_support plugins io_support windowing designers utils].each do |x|
      Dir["#{File.dirname(__FILE__)}/#{x}/*.rb"].each {|file| require file }
    end
  end

  # END INIT AREA

  def on_close_request(event)
    stop_it = false
    # TODO: multi-windows
    # TODO: I cant seem to prevent window from closing
    if false && @canvas.children.length > 0 && SD::IOSupport::DashObject.parse_scene_graph(@canvas) != @current_save_data
      answer = SD::DesignerSupport::SaveQuestion.ask(@stage)
      if answer == :cancel_oh_so_broken
        event.consume
        stop_it = true
      elsif answer == :save
        save
      end
    end
    #@aa_name_trees_threads.each{|k, v|v[1].kill}
    @data_core.dispose
    @canvas.dispose unless true # stop_it
  end

  def lock_props
    @locked_props = true
    if block_given?
      q = yield
      unlock_props
      return q
    end
  end

  def unlock_props
    @locked_props = false
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
    hide_toolbox # TODO: cheap hack
    @dnd_ids << val unless @dnd_ids.include?(val)
    @dnd_opts[val] = opts
    @dnd_ids.index(val)
  end

  def reload_toolbox_style
    @toolbox_group.each do |key, values|
      values.children.each do |val|
        val.reload_fxml
      end
    end
  end

  # Scrounge around and find everything that should go in the toolbox.
  def find_toolbox_parts
    unless @found_plugins # cache it as its expensive
      # TODO: exceptions
      SD::Plugins.load "built-in", lambda {|url|ControlRegister.java_class.resource url}

      # check for the plugins folder
      plugin_yaml = $PLUGIN_DIR
      if Dir.exist? plugin_yaml
        Dir["#{plugin_yaml}/*"].each do |plugin_path|
          SD::Plugins.load(plugin_path, if plugin_path.end_with? ".jar"
              require plugin_path
              class_loader = java.net.URLClassLoader.new([java.net.URL.new("file:#{plugin_path}")].to_java(java.net.URL))
              lambda {|url| class_loader.find_resource(url.gsub(%r{^/}, ''))}
            else
              lambda {|url| java.net.URL.new("file:#{plugin_path}/#{url}")}
            end)
        end
      end
      @toolbox_bits = SD::Plugins.controls.group_by{|x| x.category}
      @toolbox_bits.keys.each do |key|
        lfp = nil
        @accord.panes << (titled_pane(text: "Toolbox - #{key.nil? ? "Ungrouped" : key}") do
            sp = scroll_pane(fit_to_width: true, max_height: 1.0/0.0, max_width: 1.0/0.0) do
              setHbarPolicy Java::JavafxSceneControl::ScrollPane::ScrollBarPolicy::NEVER
              setPannable false
              setPrefHeight -1.0
              setPrefViewportWidth 0
              setPrefWidth -1.0
              styleClass.add "toolbox-panes"
              setContent(lfp = flow_pane(pref_height: 200, pref_width: 200))
            end
            setContent sp
          end)
        @toolbox_group[key] = lfp
      end
      @found_plugins = true
    end
    @toolbox_bits
  end

  # called to wrap the control in an overlay and to place in a control
  def add_designable_control(control, xy, parent, oobj)
    ovl = SD::DesignerSupport::Overlay
    designer = if control.is_a? ovl then
      # control.parent TODO: re-register
      control
    else
      ovl.new(control, self, parent, oobj)
    end

    # if its designable, add hooks for nested editing to work
    if control.is_a? Java::dashfx.lib.controls.DesignablePane
      designer.set_on_drag_dropped &method(:drag_drop)
      designer.set_on_drag_over &method(:drag_over)
      @layout_managers[control] = SD::Windowing::LayoutManager.new(control)
    end
    @layout_managers[parent].layout_controls({designer => xy})
    # Add it to the map so we can get the controller later if needed from UI tree
    if designer != control # don't add if it exists
      @ui2pmap[control.ui] = control
      self.message = "Added new #{oobj.id}"
    end
    designer
  end

  def ui2p(ui)
    tmp = @ui2pmap[ui]
    until tmp
      ui = ui.parent
      tmp = @ui2pmap[ui]
    end
    tmp
  end

  def add_known(name)
    return @aa_tree_hash[name] if name == "." || name == "/"
    item = name.sub(/\/$/, '')
    ti = if @aa_tree_hash.has_key? item
      @aa_tree_hash[item]
    else
      val = {value: item, fout: false}
      @aa_tree_list << val
      @aa_tree_hash[item] = tree_item(value: val, expanded: true)
    end
    children = add_known(File.dirname(item)).children
    children << ti unless children.contains ti
    ti
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
          # get the type that we are dealing with so we can filter for it
          typeo = @data_core.getObservable(id)
          #open a popup and populate it
          tbx_popup = SD::DesignerSupport::ToolboxPopup.new # TODO: cache these items so we don't have to reparse fxml
          find_toolbox_parts.each do |key, data|
            data.each do |i|
              next unless i.can_display? typeo.type, typeo.group_name
              ti = SD::DesignerSupport::ToolboxItem.new(i, method(:associate_dnd_id), :assign_name => id)
              ti.set_on_mouse_clicked do
                drop_add associate_dnd_id(i, :assign_name => id), event.x, event.y, event.source
                @on_mouse.call if @on_mouse # hide it
              end
              tbx_popup.add ti, key
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
    pare = source == current_vc.ui ? current_vc.pane : source.child
    dnd_obj = @dnd_ids[id]
    obj = dnd_obj.new # create the object that we are dragging on
    if @dnd_opts[dnd_obj]
      # TODO: check for other options
      obj.name = @dnd_opts[dnd_obj][:assign_name] if obj.respond_to? :name=
      obj.label = File.basename(@dnd_opts[dnd_obj][:assign_name]) if obj.respond_to? :label=
    end
    add_designable_control obj, MousePoint.new(x, y), pare, @dnd_ids[id]
    hide_toolbox
    @clickoff_fnc.call if @clickoff_fnc
    @on_mouse.call(nil) if @on_mouse
  end

  def morph_child(overlay, event) #TODO: drip drip drip leakage
    # TODO: filter for types
    tbx_popup = SD::DesignerSupport::ToolboxPopup.new # TODO: cache these items so we don't have to reparse fxml
    find_toolbox_parts.each do |key, data| # TODO: grouping and sorting
      next if key == "Grouping"
      data.each do |i|
        ti = SD::DesignerSupport::ToolboxItem.new(i, method(:associate_dnd_id))
        ti.set_on_mouse_clicked do
          obj = i.new
          yield(obj, i)
          @ui2pmap[obj.ui] = obj
          self.message = "Added new #{obj.java_class.name}"
          hide_toolbox
          @clickoff_fnc.call if @clickoff_fnc
          @on_mouse.call(nil) if @on_mouse
        end
        tbx_popup.add ti, key
      end
    end
    # position the popup at the location of the mouse
    tbx_popup.x = overlay.local_to_scene(overlay.bounds_in_local).min_x + @stage.x
    tbx_popup.y = overlay.local_to_scene(overlay.bounds_in_local).min_y + @stage.y
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
    self.running = true
    hide_controls
    hide_toolbox
    hide_properties
  end

  def design
    @mode = :design
    self.running = false
    show_controls
  end

  def hide_controls
    animate_controls(true)
  end

  # this is for play/pause bottom gutter hiding/showing
  def animate_controls(hide)
    mul = hide ? -1 : 1
    nul = hide ? 0 : 1
    # TODO: this should be cleaned up
    bg = @bottom_gutter
    sbs = [@stop_button, @playback_button]
    stg = @stage
    oy = stg.y
    ox = stg.x
    # The properties are read only because of OS issues, so we just create a proxy
    stg_hap = SimpleDoubleProperty.new(stg.height)
    stg_hap.add_change_listener {|ov, old, new| stg.setHeight(new); stg.y = oy; stg.x = ox; }
    timeline do
      animate bg.translateYProperty, 0.ms => 500.ms, (32 * nul) => (32 - 32 * nul)
      sbs.each do |sb|
        animate sb.visibleProperty, 0.ms => 500.ms, (!hide) => hide
      end
      animate stg_hap, 0.ms => 500.ms, stg.height => (stg.height + 32 * mul)
      animate bg.pref_height_property, 0.ms => 500.ms, (32 - 32 * nul) => (32 * nul)
    end.play
  end


  def show_controls
    animate_controls(false)
  end

  # set the popup message at the bottom
  def message=(msg)
    am = @alert_msg
    with(@msg_carrier) do |mc|
      timeline do
        animate mc.translateYProperty, 0.sec => [200.ms, 5.sec, 5.2.sec], 30.0 => [0.0, 0.0, 30.0]
        animate mc.minWidthProperty, 0.sec => [200.ms, 5.sec, 5.2.sec], 0 => [200, 200, 0]
        animate am.textProperty, 0.sec => [200.ms, 5.sec, 5.2.sec, 5.21.sec], "" => [msg, msg, msg, ""]
      end.play
    end
  end

  def save
    if @currently_open_file
      save_file(@currently_open_file)
    else
      save_as
    end
  end

  def save_as
    dialog = file_chooser(:title => "Save Layout...") do
      add_extension_filter("-fx:SmartDashboard save files (*.fxsdash)")
    end
    file = dialog.showSaveDialog(@stage)
    return unless file
    save_file file.path
  end

  def save_file(file)
    file += ".fxsdash" unless file.end_with? ".fxsdash"
    File.open(file, "w") do |io|
      Gem::Package::TarWriter.new(io) do |tar|
        tar.add_file("version", 0644) {|f|f.write("0.1")}
        tar.add_file("data.yml", 0644) do |yml|
          psg = SD::IOSupport::DashObject.parse_scene_graph(@view_controllers.to_a, @data_core)
          yml.write YAML.dump(psg)
          @current_save_data = psg
        end
      end
    end
    self.message = "Saved!"
    @stage.title = "SmartDashboard : #{File.basename(file, ".fxsdash")}"
    @currently_open_file = file
    update_recent_opens(file)
    build_open_menu
  end

  def update_recent_opens(new)
    recently_open = @prefs.recently_open
    if recently_open.include? new
      # remove it and put it at the front
      recently_open -= [new]
    end
    recently_open = ([new] + recently_open).first(10)
    @prefs.recently_open = recently_open
  end

  def build_open_menu
    recently_open = @prefs.recently_open
    this = self
    with(@open_btn) do
      items.clear
      menu_item("Open", style: "-fx-font-weight: bold").on_action {this.open}
      separator_menu_item
      recently_open.each do |i|
        menu_item(File.basename(i, ".fxsdash")).on_action do
          this.open_file(i)
        end
      end
    end
  end

  def open
    dialog = file_chooser(:title => "Open Layout...") do
      add_extension_filter("-fx:SmartDashboard save files (*.fxsdash)")
    end
    file = dialog.show_open_dialog(@stage)
    return unless file
    open_file(file.path)
  end

  def open_file(file)
    update_recent_opens(file)
    build_open_menu
    data = {} # TODO: very memory inefficient
    File.open(file, "r") do |io|
      Gem::Package::TarReader.new(io) do |tar|
        tar.each do |entry|
          data[entry.full_name] = entry.read
        end
      end
    end
    if data["version"].to_f != 0.1
      self.message = "Unknown file version '#{data["version"]}'"
      return
    end
    doc =  YAML.load(data['data.yml'])
    @current_save_data = doc
    # TODO: tab support
    clear_tabs()
    @aa_ignores = doc.known_names
    vc_first = nil
    doc.vcs.each do |ro|
      vc = ro.new
      vc_first = vc unless vc_first
      add_tab(vc)
      ro.children.each {|x| open_visitor(x, vc.pane)}
    end
    tab_select(vc_first.tab)
    @currently_open_file = file
    @stage.title = "SmartDashboard : #{File.basename(file, ".fxsdash")}"
    self.message = "File Load Successfull"
  end

  def open_visitor(cdesc, parent)
    desc = SD::Plugins::ControlInfo.find(cdesc.object)
    obj = desc.new
    obj.ui.setPrefWidth cdesc.sprops["Width"] if cdesc.sprops["Width"] > 0
    obj.ui.setPrefHeight cdesc.sprops["Height"] if cdesc.sprops["Height"] > 0
    add_designable_control(obj, MousePoint.new(cdesc.sprops["LayoutX"], cdesc.sprops["LayoutY"], false), parent, desc)
    cdesc.props.each do |prop, val|
      nom = "set#{prop}"
      next if prop == "Value"
      if obj.respond_to? nom
        obj
      else
        obj.ui
      end.send(nom, (val.kind_of?(SD::IOSupport::ComplexObject) ? val.to_value : val))
    end
    cdesc.children.each {|x| open_visitor(x, obj) }
  end

  def new_document
    # TODO: check for unsaved changes
    # assign the root canvas node from preferences
    @current_save_data = @currently_open_file = nil
    @stage.title = "SmartDashboard : Untitled"
    clear_tabs()
    # TODO: don't copy this in the ctor

    main_vc = SD::Windowing::DefaultViewController.new
    main_vc.on_focus_request do |focus|
      tab_auto_focus(main_vc, focus)
    end
    main_tab = add_tab(main_vc)
    SD::Plugins.view_controllers.find_all{|x|x.default > 0}.each do |x|
      vc = x.new
      vc.on_focus_request do |focus|
        tab_auto_focus(vc, focus)
      end
      add_tab(vc)
    end
    tab_select(main_tab)
  end

  def hide_properties
    if @properties
      @properties.hide
    end
  end

  def update_properties
    if @selected_items.length < 1 or @selected_items.find_all { |i| !i.editing_nested }.length != 1
      @propertiesFor = @selected_items[0]
      hide_properties
    else
      # don't clobber open/close stats
      if @propertiesFor != @selected_items[0]
        @propertiesFor = @selected_items[0]
        @properties.properties = @selected_items[0].properties
      end
      sic = @selected_items[0].child
      name = sic.name if sic.respond_to? :name
      name = @selected_items[0].original_name unless name && name != ""
      name = sic.java_class.name.split(".").last unless name && name != ""
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
    scr = Screen.getScreensForRectangle(scr_x + bnds.min_x, scr_y + bnds.min_y, 1, 1)[0]
    unless scr
      lamb = lambda{|x,y|Screen.getScreensForRectangle(scr_x + x, scr_y + y, 1, 1)[0]}
      scr = lamb.call(bnds.max_x, bnds.max_y) || lamb.call(bnds.max_x, bnds.min_y) || lamb.call(bnds.min_x, bnds.max_y) || Screen.primary
    end
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

  def show_hide_toolbox
    if @toolbox_status == :hidden
      show_toolbox
    else
      hide_toolbox
    end
  end

  def hide_toolbox
    return if @toolbox_status == :hidden
    @toolbox_status = :hidden
    asl = @add_slider
    gshadow = @gutter_shadow
    @clickoff_tbx = Proc.new {|x|}
    @on_tmouse.call if @on_tmouse
    with(@left_gutter) do |tbx|
      timeline do
        animate tbx.translateXProperty, 0.ms => 500.ms, 0.0 => -266.0
        animate asl.minWidthProperty, 0.ms => 500.ms, 268.0 => 0.0
        animate gshadow.translateXProperty, 0.ms => 500.ms, 266.0 => 0.0
        animate gshadow.minWidthProperty, 100.ms => 500.ms, 30.0 => 0.0
      end.play
    end
  end

  def show_toolbox
    hide_properties
    return if @toolbox_status == :visible
    @toolbox_status = :visible
    asl = @add_slider
    gshadow = @gutter_shadow
    with(@left_gutter) do |tbx|
      timeline do
        animate tbx.translateXProperty, 0.sec => 500.ms, -266.0 => 0.0
        animate asl.minWidthProperty, 0.ms => 500.ms, 0.0 => 268.0
        animate gshadow.translateXProperty, 0.ms => 500.ms, 0.0 => 266.0
        animate gshadow.minWidthProperty, 0.ms => 400.ms, 0.0 => 30.0
      end.play
    end
    register_toolbox_clickoff do
      hide_toolbox
    end
  end

  def canvas_click(e)
    hide_properties
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
    end while (q = q.parent) && q != current_vc.pane
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

  def try_reparent(child, x, y)
    @last_reparent_try.hide_nestable if @last_reparent_try
    @last_reparent_try = nil
    #    puts "----"
    #    current_vc.ui.children.each do |ch|
    #      if ch.is_a? SD::DesignerSupport::Overlay
    #        ch.print_tree
    #      else
    #        p ch
    #      end
    #    end
    #    puts "--"
    try_reparent_cc([SD::DesignerSupport::OverlayRootWrapper.new(current_vc.ui, !@nested_list[current_vc].last)], child, x, y)
  end

  def try_reparent_cc(ui, child, x, y)
    childs = ui.reverse
    if new_parent = childs.find { |n| n != child && n.can_nest? && n.is_inside?(x,y) }
      if !try_reparent_cc(new_parent.child.children.to_a, child, x, y)
        if new_parent.child.children.include?(child) # TODO:  && n != child.parent ????
          return true if new_parent.editing_nested
          return try_reparent_cc(ui - [new_parent], child, x, y)
        end
        @last_reparent_try = new_parent
        new_parent.show_nestable
      end
      true
    else
      @last_reparent_try = nil
      false
    end
  end

  def reparent!(child, x, y)
    child.parent.children.remove(child)
    add_designable_control(child, MousePoint.new(*@last_reparent_try.scene_to_local(x, y), false), @last_reparent_try.child, nil)
    @last_reparent_try.hide_nestable
    @last_reparent_try = nil
  end

  # TODO: store this state on the overlay control if possible
  def reparent?
    !!@last_reparent_try
  end

  def do_playback_mode
    @playback.launch
  end

  def delete_selected
    @selected_items.each do |si|
      # Remove the item from its parent, this supports nesting ad-infinitum
      si.parent.children.remove(si)
    end
    @selected_items = []
    hide_properties
  end

  def canvas_keyup(e)
    if e.code == KeyCode::DELETE
      delete_selected
      e.consume
    elsif e.control_down?

      callback = {
        KeyCode::R => lambda{@mode == :run ? design : run} ,
        KeyCode::S => lambda{save},
        KeyCode::O => lambda{open},
        KeyCode::N => lambda{new_document},
        KeyCode::F => lambda{show_toolbox; aa_show_regex_panel},
        KeyCode::TAB => lambda{focus_related_tab(e.shift_down? ? -1 : 1)}

      }[e.code]
      callback.call if callback
    end
  end

  def compute_wingmen(chb)
    parb = @spain.local_to_scene(@spain.bounds_in_local)
    # north east south west (css style)
    OpenStruct.new(north: chb.min_y - parb.min_y, east: parb.max_x - chb.max_x,
      width: parb.width, south: parb.max_y - chb.max_y, west: chb.min_x - parb.min_x)
  end

  def show_wingmen(child)
    nesting = !!child
    @wingman[current_vc] = child
    @north_wing.visible = @south_wing.visible = @east_wing.visible = @west_wing.visible = nesting

    if nesting
      ccb = child.control_bounds
      tmp = compute_wingmen(ccb)
    end
    @west_wing.pref_width = nesting ? tmp.west : 0
    @east_wing.pref_width = nesting ? tmp.east : 0 # TODO: binding
    @west_wing.layout_y = @east_wing.layout_y = @north_wing.pref_height = nesting ? tmp.north : 0
    @south_wing.pref_height = nesting ? tmp.south : 0

    @west_wing.pref_height = @east_wing.pref_height = ccb.height if nesting
  end

  def nested_edit(octrl)
    return false if @mode == :run
    show_wingmen(octrl)
    @nested_list[current_vc] << octrl
    return true
  end

  def surrender_nest(e)
    if e.click_count > 1 # Run away!
      @nested_list[current_vc].length > 0 && @nested_list[current_vc].pop.exit_nesting
      show_wingmen(@nested_list[current_vc].last)
    end
  end

  # helper function for traversing parents when nesting editing
  def nested_traverse(octrl, after, &eachblock)
    return if octrl == current_vc.ui || octrl == (@last_nested && @last_nested.last)
    ctrl = octrl
    begin
      saved = (ctrl.parent.children.to_a.find_all{|i| i != ctrl})
      saved.each &eachblock
      after.call(ctrl)
      ctrl = ctrl.parent
    end while ctrl != current_vc.ui && ctrl != (@last_nested && @last_nested.last)
  end

  # Settings for the canvas TODO: add other canvas properties
  def show_data_sources
    require 'data_source_selector'
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
    aa_add_some(current_vc.pane, *@aa_tree.root.children.map{|x| x.value[:value]}.find_all{|x| !@aa_regex_showing || x.match(@aa_filter.regex)})
  end

  def aa_add_some(pane, *names)
    names.each do |ctrl_name|
      ctrl = @data_core.get_observable(ctrl_name)
      begin
        new_objd = if !ctrl.type || ctrl.type == 64
          SD::Plugins.controls.find{|x| x.group_types == ctrl.group_name}
        else
          SD::DesignerSupport::PrefTypes.for(ctrl.type)
        end
        new_obj = new_objd.new
        if new_obj
          add_designable_control with(new_obj, name: ctrl.name), NilPoint.new, pane, new_objd
        else
          puts "Warning: no default control for #{ctrl.type.mask}"
        end
      rescue
        puts "Warning: error finding default control for #{ctrl}"
      end
    end
    hide_toolbox
  end
  # TODO: next few lines can be cleaned up im sure
  def aa_add_new
    @aa_filter.always_add = !@aa_filter.always_add
  end

  def aa_hide_regex_panel
    @aa_ctrl_panel.children.remove(@aa_ctrl_regex)
    @aa_expand_panel.text = "V"
  end

  def aa_show_regex_panel
    @aa_ctrl_panel.children.add(@aa_ctrl_regex)
    @aa_expand_panel.text = "^"
    @aa_regexer.request_focus
  end

  def aa_toggle_panel
    @aa_regex_showing = !@aa_regex_showing
    if @aa_regex_showing
      aa_show_regex_panel
    else
      aa_hide_regex_panel
    end
  end

  def current_vc
    @view_controllers[vc_index]
  end

  def new_tab
    @count ||= 0
    @count += 1
    new_vc = SD::Windowing::DefaultViewController.new("NewTab-#{@count}", false)
    btn = add_tab(new_vc)
    tab_select(btn)
    delete_it = lambda{delete_tab btn}
    btn.graphic = button("x"){
      set_on_action do |e|
        delete_it.call
        e.consume
      end
      style_class << "delete"
    }
    btn.content_display = Java::javafx.scene.control.ContentDisplay::RIGHT
  end

  def delete_tab(tab)
    vc = @view_controllers.find{|x| x.tab == tab}
    @view_controllers.remove vc
    @tab_box.children.remove(tab)
    @aa_name_trees.delete(vc)
    @aa_name_trees_threads.delete(vc) # TODO: kill thread
    @ui2pmap.delete vc.pane
    @ui2pmap.delete vc.ui
    tab_select(@view_controllers[0].tab)
  end

  def add_tab(vc)
    vc.tab = button(vc.name)
    vc.tab.set_on_action &method(:tab_clicked)
    @view_controllers << vc
    @tab_box.children.add(@tab_box.children.length - 1, vc.tab)
    os = OpenStruct.new({can_nest?: true, child: vc.pane})
    @aa_name_trees[vc] = SD::DesignerSupport::AANameTree.new("", SD::DesignerSupport::AANameTree.new("", os, proc{}).tap{|x|x.data[:descriptor] = os}, proc{})
    @aa_name_trees_threads[vc] = [Mutex.new, Thread.new do
        loop {
          Thread.stop
          tdiff = (@aa_name_trees_threads[vc][3] + 0.5) - Time.now
          while tdiff > 0
            sleep(tdiff)
            tdiff = (@aa_name_trees_threads[vc][3] + 0.5) - Time.now
          end
          run_later do
            @aa_name_trees_threads[vc][0].synchronize do
              @aa_name_trees[vc].process method(:add_designable_control)
            end
          end
        }
      end, lambda{|x| @aa_name_trees_threads[vc][3] = x}, Time.now]
    @ui2pmap[vc.pane] = vc
    @ui2pmap[vc.ui] = vc.pane
    @layout_managers[vc.pane] = vc.layout_manager
    @layout_managers[vc.ui] = vc.layout_manager
    vc.pane.registered(@data_core)
    @nested_list[vc] = []
    return vc.tab
  end


  def focus_related_tab(which)
    tab_select(@view_controllers[(vc_index + which) % @view_controllers.length].tab)
  end

  def tab_select(tab)
    hide_properties
    hide_toolbox
    vc = @view_controllers.find{|x|x.tab == tab}
    @view_controllers.each do |lm|
      lm.tab.style_class.remove("active")
    end
    vc.tab.style_class.add("active")
    self.root_canvas = vc
    @vc_index.value = @view_controllers.index(vc)
    vc.ui.request_layout # force layout to avoid extra blank screen + click? is this needed?
    show_wingmen @wingman[current_vc]
  end

  def tab_clicked(e)
    @vc_focus = [] # when we manually click, make it default to current
    tab_select(e.target)
  end

  def tab_auto_focus(vc, focus)
    unless focus
      @vc_focus -= [vc]
    else
      if @vc_focus.include? vc or @view_controllers[vc_index] == vc
        return # there will be no pillaging tonight
      end
      @vc_focus << vc
      if @vc_focus.length == 1
        @vc_focus = [@view_controllers[vc_index]] + @vc_focus
      end
    end
    tab_select(@vc_focus.last.tab) if @vc_focus.length > 0
  end

  def clear_tabs
    @tab_box.children.remove_all(*@view_controllers.map(&:tab))
    @view_controllers.clear
    @vc_index.value = 0
    @aa_name_trees = {}
    @aa_name_trees_threads = {}
    @ui2pmap = {}
  end

  # edit the smart dashboard settings
  def edit_settings
    hide_properties
    require 'settings_dialog'
    stg = @stage
    this = self
    stage(init_style: :utility, init_modality: :app, title: "SmartDashboard Settings") do
      init_owner stg
      fxml SD::SettingsDialog, :initialize => [this]
      show_and_wait
    end
  end

  # Assign the designer surface and set up handlers
  def root_canvas=(cvs)
    @overlay_pod.children.remove @cur_canvas.ui if @cur_canvas
    @overlay_pod.children.add 0, cvs.ui
    raise "overlay pod has #{@overlay_pod.children.length} children instead of expected 5" unless @overlay_pod.children.length == 5
    @cur_canvas = cvs
    cvs.ui.min_width_property.bind(@spain.width_property.subtract(2.0))
    cvs.ui.min_height_property.bind(@spain.height_property.subtract(2.0))
    cvs.ui.pref_width = -1 # autosize
    cvs.ui.pref_height = -1 # autosize
    @overlay_pod.pref_width_property.bind cvs.ui.width_property
    @overlay_pod.pref_height_property.bind cvs.ui.height_property
    @layout_managers[cvs.pane] = cvs.layout_manager
    @layout_managers[cvs.ui] = cvs.layout_manager
    cvs.ui.setOnDragDropped &method(:drag_drop)
    cvs.ui.setOnDragOver &method(:drag_over)
    cvs.ui.setOnMouseReleased &method(:canvas_click)
  end

  def force_layout
    @cur_canvas.ui.request_layout
  end

  def self.instance
    @@singleton
  end
end
# require stuff in the background
SD::Designer.require_thread