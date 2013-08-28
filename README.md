# SFX
(AKA SmartDashboardNG AKA SmartDashboard 2 AKA SmartDashboard 3)

## Rough Arch overview (sfx*)
### Data
Data is found via `DataSource`s on their own threads (spawned on `setProcessor`), and then send to the data core via `processData` inside a transaction which consists of deleted values (unused at the moment), and updated values (`SmartValue`s).
The DataCore then sends the transaction to any filters (such as playback) via `processData`, which can a) swallow the transaction b) modify the transaction c) passthrough the transaction at their own leisure. Filters call `processData` on their processors, which can either be the DataCore as in the current configuration, or a direct pipe to the next filter.

Once all Filters have processed the transactions, the core splits the transactions up and merges it with its master tree of `SmartValue`s. A `SmartValue` is an ObservableValue with a few more bits of data suck on (name, purported type, group names (aka ~TYPE~)). I'm not entirely satisfied with the current design of them (sending data back, non observable properties), but it works. `Control`s can get bits of the tree by calling `getObservable` on the core, which ALWAYS returns a `SmartValue`, even if the name has not been seen before. This lets controls register themselves before any data has come in and it will seamlessly start changing when it does. Currently, if manually typing a name/path, the tree fills up with mistypings since it does not use weak refs, which it should, except in cases of Data in before controls (see invisible gollumn in test data source)

Once the `Control` has a `SmartValue`, it can listen for change events (ObservableValue, so standard JavaFX Observable* events) and get correctly re-formatted data via `getData().asXxxx()`. Using `getValue()` is not recommended as its not type-safe. Change events are normally data coming in from outside sources but can also be filters generating data (like Playback). There is unfortunatly no way to currently detect this. If a control wants to send data back, just call `setData` on the `SmartValue` with an adapter that suits the value, such as `DoubleSmartValue` for `2.79` or `StringSmartValue` for `"Win game"`. I'm not sure I like this, but its better than it was.

When the core detects a change to a `SmartValue`, it will then attempt to send it to the first registered `DataSource`. This is because I have not implemented multi-sending yet. It should find the correct path to send it to, unprefix the name, and send it to that.

### Controls / Designer / Plugins

All Controls must inherit from `Control` and are described via annotations and/or manifest descriptors. All the manifests are YAML and each manifest describes one discrete plugin component. Plugins contain `Control`s, `ViewController`s, and more (eventualy, like Data*). Controls can be written in Java, FXML only, or JRuby. Java classes are pointed to using `Class`, FXML `Source`, and JRuby both `Source` and `Class` (See SFX/plugins/built-in/manifest.yml for details). Java classes can have annotations also, like `@Designable` and `@Category`.

When SFX starts up, it searches for plugins in $PWD/plugins/. Plugins can be a raw directory (such as SFX/plugins/builtin) or a jar file (like live window plugin). in each case, they need a manifest.yml file to describe them, though java-only controls should support classpath searching, but that is not done.

Once the plugins are loaded, any `ViewController`s are activated (LiveWindow) and `Control`s are put in the toolbox. If any SmartValue comes in that matches a control, it is placed on the canvas. `ViewController`s manage how they are placed. When a control is clicked on (actually an `OverlayControl`, `@Designable` properties appear in a (horrible looking, needs improvement) properties dialog. This dialog finds appropriate designers (defaults are in SFX/lib/designers) for the given type of the return type of the getter, or overridable. `@Designable` MUST be applied to the bean-style function `xProperty` and `getX` or `isX` must exist (just like FXML).

There are several built-in helpers for building FXML-only controls

### Code
sfxmeta contains annotation processors used to find all the controls in sfxlib and generate a list of them.
sfxlib contains all the data processing stuff, some base control bases, and some base controls.
SFX contains the designer/all the UI.
LiveWindowPlugin contains, well, live window

## Netbeans Install
Install http://plugins.netbeans.org/plugin/38549 into netbeans 7.3

Run `ant` (to rebuild, `ant fast`)

if only using netbeans, edit the properties for running to point to gems/* instead of ../* (except ../sfx*)

Or if you have a jruby install, clone jrubyfx and jrubyfx-fxmlloader (gem install jrubfyx)

Then import all 3/4 projects, rebuild sfxlib and run SFX.
