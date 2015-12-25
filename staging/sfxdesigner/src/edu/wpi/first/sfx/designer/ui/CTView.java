/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package edu.wpi.first.sfx.designer.ui;

import dashfx.lib.controls.Category;
import dashfx.lib.controls.Control;
import dashfx.lib.controls.Designable;
import dashfx.lib.controls.DesignablePane;
import dashfx.lib.controls.DesignableProperty;
import dashfx.lib.controls.ResizeDirections;
import dashfx.lib.rt.ControlMetaInfo;
import dashfx.lib.util.ControlTree;
import edu.wpi.first.sfx.designer.util.Property;
import java.io.IOException;
import java.lang.annotation.Annotation;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.net.URL;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.ResourceBundle;
import java.util.concurrent.CompletableFuture;
import java.util.logging.Level;
import java.util.logging.Logger;
import javafx.beans.binding.Bindings;
import javafx.beans.binding.BooleanBinding;
import javafx.beans.binding.ObjectBinding;
import javafx.beans.property.SimpleBooleanProperty;
import javafx.beans.value.ObservableValue;
import javafx.event.*;
import javafx.fxml.*;
import javafx.geometry.Bounds;
import javafx.scene.Group;
import javafx.scene.Node;
import javafx.scene.control.ContextMenu;
//import javafx.scene.control.*;
import javafx.scene.input.*;
import javafx.scene.layout.*;
import javafx.scene.paint.Color;
import javafx.scene.shape.Rectangle;
import javafx.scene.shape.Shape;

/**
 *
 * @author patrick
 */
public class CTView extends GridPane
{

	private final ControlTree tree;
	private final DesignerMetadata meta;
	private CompletableFuture<Control> future;
	private Control child;

	@FXML
	private ResourceBundle resources;

	@FXML
	private URL location;

	@FXML
	private Group groupMax;

	@FXML
	private BorderPane childContainer;

	@FXML
	private ContextMenu context_menu;

	@FXML
	private Rectangle eHandle;

	@FXML
	private Region eResizeRegion;

	@FXML
	private Region moveRegion;

	@FXML
	private Rectangle nHandle;

	@FXML
	private Region nResizeRegion;

	@FXML
	private Region neResizeRegion;

	@FXML
	private Region nwResizeRegion;

	@FXML
	private Pane overlay;

	@FXML
	private Rectangle sHandle;

	@FXML
	private Region sResizeRegion;

	@FXML
	private Region seResizeRegion;

	@FXML
	private GridPane selected_ui;

	@FXML
	private Region swResizeRegion;

	@FXML
	private Rectangle wHandle;

	@FXML
	private Region wResizeRegion;

	private boolean can_nested_edit()
	{
		return child instanceof DesignablePane;
	}

	public List<Property> findAllProperties()
	{
		ArrayList<Property> pl = new ArrayList<>();
		// TODO: full overlay_control algo needs to go here
		DesignableProperty a = child.getClass().getAnnotation(DesignableProperty.class);
		if (a != null)
		{
			for (int i = 0; i < a.value().length; i++)
			{
				String name = a.value()[i];
				String getName = "get" + name.substring(0, 1).toUpperCase() + name.substring(1);
				try
				{
					Class getType = child.getClass().getMethod(getName).getReturnType();

					pl.add(new Property(name, a.descriptions()[i], getType, (javafx.beans.property.Property) child.getClass().getMethod(name + "Property").invoke(child), "General"));// TODO: category
				}
				catch (IllegalAccessException | IllegalArgumentException | InvocationTargetException | NoSuchMethodException | SecurityException ex)
				{
					System.err.println("Failed to open the property");
					ex.printStackTrace();
				}
			}
		}
		for (Method m : child.getClass().getMethods())
		{
			Designable annote = m.getAnnotation(Designable.class);
			if (annote != null)
			{
				String name = m.getName();
				if (name.startsWith("get") || name.startsWith("set"))
				{
					System.out.println("FAIL!");
					name = name.substring(3, 4).toLowerCase() + name.substring(4);
				}
				else
				{
					if (name.endsWith("Property"))
					{
						name = name.substring(0, name.length() - 8);
					}
				}

				Category cate = m.getAnnotation(Category.class);
				String category = cate == null ? "General" : cate.value();
				String getName = "get" + name.substring(0, 1).toUpperCase() + name.substring(1);
				try
				{
					Class getType = child.getClass().getMethod(getName).getReturnType();
					if (annote.value() != null)
					{
						name = annote.value();
					}

					pl.add(new Property(name, annote.description(), getType, (javafx.beans.property.Property) m.invoke(child), category));
				}
				catch (IllegalAccessException | IllegalArgumentException | InvocationTargetException | NoSuchMethodException | SecurityException ex)
				{
					System.err.println("Failed to open the property");
					ex.printStackTrace();
				}
			}
		}
		return pl;
	}

	@FXML
	void checkDblClick(MouseEvent e)
	{
		System.out.println("ClickCT" + ((Object) this).hashCode());
		if (e.getClickCount() > 1 && can_nested_edit())
		{
			// enable nested mode!
			if (!editing_nested.get())
			{
				System.out.println("Tryint");
				meta.setEditing(tree);
				e.consume();
			}
		}
		else
		{
			if (meta.getEditing() == tree)
			{
				meta.setSelected(null);
			}
			else
			{
				if (meta.getSelected() != tree)
				{
					meta.setSelected(tree);
				}
			}
			e.consume();
		}
	}

	@FXML
	void delete(ActionEvent event)
	{
	}

	@FXML
	void dragDone(MouseEvent event)
	{
		if (drag_action != null)
		{
			((DesignablePane) getCTParent().child).FinishDragging();
			// @parent_designer.properties_dragshow(self)
       /* if @parent_designer.reparent?
			 bnds = local_to_scene(bounds_in_local.min_x, bounds_in_local.min_y)
			 @parent_designer.reparent!(self, bnds.x, bnds.y)
			 end*/
		}
		drag_action = null;
	}

	private double[] drag_action = null;

	@FXML
	void dragUpdate(MouseEvent e)
	{
		if (editing_nested.get()) // # TODO: something is wrong here...
		{
			throw new RuntimeException("Something very wrong happened");
		}
		if (drag_action != null)
		{
			//TODO: Don't assume designable pane
			((DesignablePane) getCTParent().child).ContinueDragging(e.getSceneX() - drag_action[0], e.getSceneY() - drag_action[1]);
//        @parent_designer.force_layout
//        @parent_designer.try_reparent(self, e.scene_x, e.scene_y) if e.target == @moveRegion
		}
		else
		{
			if (true) //( @supported_ops.include? e.target.id.to_sym)
			{
				/*		  nodes = [self]
				 if original && (e.control_down? || @parent_designer.multiple_selected?)
				 nodes += @parent_designer.multi_drag(self)
				 end*/
				drag_action = new double[]
				{
					e.getSceneX(), e.getSceneY()
				};
				// @parent_designer.properties_draghide()
				DesignablePane dp = (DesignablePane) getCTParent().child;
				FourTouple ft = DIRECTIONS.get(((Node) e.getTarget()).getId());
				dp.BeginDragging(new Node[]
				{
					this
				}, new Region[]
						 {
							 childContainer
				}, e.getSceneX(), e.getSceneY(), ft.data[0], ft.data[1], ft.data[2], ft.data[3]);
			}
		}
		e.consume();
	}

	private CTView getCTParent()
	{
		return meta.getAssociatedView(tree.getParent());
	}

	@FXML
	void request_ctx_menu(ContextMenuEvent event)
	{
	}

	@FXML
	void z_send_backward(ActionEvent event)
	{
	}

	@FXML
	void z_send_bottom(ActionEvent event)
	{
	}

	@FXML
	void z_send_forward(ActionEvent event)
	{
	}

	@FXML
	void z_send_top(ActionEvent event)
	{
	}

	@FXML
	void initialize()
	{
		assert childContainer != null : "fx:id=\"childContainer\" was not injected: check your FXML file 'DesignerOverlayControl.fxml'.";
		assert context_menu != null : "fx:id=\"context_menu\" was not injected: check your FXML file 'DesignerOverlayControl.fxml'.";
		assert eHandle != null : "fx:id=\"eHandle\" was not injected: check your FXML file 'DesignerOverlayControl.fxml'.";
		assert eResizeRegion != null : "fx:id=\"eResizeRegion\" was not injected: check your FXML file 'DesignerOverlayControl.fxml'.";
		assert moveRegion != null : "fx:id=\"moveRegion\" was not injected: check your FXML file 'DesignerOverlayControl.fxml'.";
		assert nHandle != null : "fx:id=\"nHandle\" was not injected: check your FXML file 'DesignerOverlayControl.fxml'.";
		assert nResizeRegion != null : "fx:id=\"nResizeRegion\" was not injected: check your FXML file 'DesignerOverlayControl.fxml'.";
		assert neResizeRegion != null : "fx:id=\"neResizeRegion\" was not injected: check your FXML file 'DesignerOverlayControl.fxml'.";
		assert nwResizeRegion != null : "fx:id=\"nwResizeRegion\" was not injected: check your FXML file 'DesignerOverlayControl.fxml'.";
		assert overlay != null : "fx:id=\"overlay\" was not injected: check your FXML file 'DesignerOverlayControl.fxml'.";
		assert sHandle != null : "fx:id=\"sHandle\" was not injected: check your FXML file 'DesignerOverlayControl.fxml'.";
		assert sResizeRegion != null : "fx:id=\"sResizeRegion\" was not injected: check your FXML file 'DesignerOverlayControl.fxml'.";
		assert seResizeRegion != null : "fx:id=\"seResizeRegion\" was not injected: check your FXML file 'DesignerOverlayControl.fxml'.";
		assert selected_ui != null : "fx:id=\"selected_ui\" was not injected: check your FXML file 'DesignerOverlayControl.fxml'.";
		assert swResizeRegion != null : "fx:id=\"swResizeRegion\" was not injected: check your FXML file 'DesignerOverlayControl.fxml'.";
		assert wHandle != null : "fx:id=\"wHandle\" was not injected: check your FXML file 'DesignerOverlayControl.fxml'.";
		assert wResizeRegion != null : "fx:id=\"wResizeRegion\" was not injected: check your FXML file 'DesignerOverlayControl.fxml'.";

	}

	private CTView getNestedAbove(ControlTree nv)
	{
		ControlTree child = nv;
		while (child != null)
		{
			CTView parent = meta.getAssociatedView(child.getParent());
			if (parent == this)
			{
				return meta.getAssociatedView(child);
			}
			child = child.getParent();
		}
		return null;
	}

	private void editingChanged(ControlTree nv)
	{
		// TODO: care about selections
		// TODO: this is very inefficient. A proper tree traveral algo will improve on this n^2 algo and make it more like n
		editing_nested.set(nv == tree);
		CTView ctv = getNestedAbove(nv);
		if (ctv != null) // if we are not the root, show the other UI
		{
			if (area == null)
			{
				initOverlay(ctv);
			}
			else
			{
				area.setChild(ctv.boundsInParentProperty(), ctv);

			}
			ssnVisible = true;
			if (ssn != null)
			{
				ssn.setVisible(true);
			}
		}
		else
		{
			if (ssn != null)
			{
				ssn.setVisible(false);
			}
			else
			{
				if (nv != tree.getParent())
				{
					editing_nested.set(true); // UI hack.... TODO: cleanup
				}
			}
		}
	}

	public static class FourTouple
	{

		public int[] data;

		public FourTouple(int x, int y, int z, int w)
		{
			data = new int[]
			{
				x, y, z, w
			};
		}
	}

	private static final HashMap<String, FourTouple> DIRECTIONS;
	private static final HashMap<ResizeDirections, Object> RESIZABILITY_MAPPER;
	public static final DataFormat JAVA_CLASS_DATA_FORMAT;

	static
	{
		DIRECTIONS = new HashMap<>();
		DIRECTIONS.put("moveRegion", new FourTouple(0, 0, 1, 1));
		DIRECTIONS.put("nwResizeRegion", new FourTouple(-1, -1, 1, 1));
		DIRECTIONS.put("nResizeRegion", new FourTouple(0, -1, 0, 1));
		DIRECTIONS.put("neResizeRegion", new FourTouple(1, -1, 0, 1));
		DIRECTIONS.put("eResizeRegion", new FourTouple(1, 0, 0, 0));
		DIRECTIONS.put("seResizeRegion", new FourTouple(1, 1, 0, 0));
		DIRECTIONS.put("sResizeRegion", new FourTouple(0, 1, 0, 0));
		DIRECTIONS.put("swResizeRegion", new FourTouple(-1, 1, 1, 0));
		DIRECTIONS.put("wResizeRegion", new FourTouple(-1, 0, 1, 0));

		RESIZABILITY_MAPPER = new HashMap<>();
		RESIZABILITY_MAPPER.put(ResizeDirections.Move, new String[]
						{
							"moveRegion"
		});
		RESIZABILITY_MAPPER.put(ResizeDirections.UpDown, new String[]
						{
							"nResizeRegion", "sResizeRegion", "nHandle", "sHandle"
		});
		RESIZABILITY_MAPPER.put(ResizeDirections.LeftRight, new String[]
						{
							"eResizeRegion", "wResizeRegion", "eHandle", "wHandle"
		});
		RESIZABILITY_MAPPER.put(ResizeDirections.SouthEastNorthWest, new String[]
						{
							"nwResizeRegion", "seResizeRegion"
		});
		RESIZABILITY_MAPPER.put(ResizeDirections.NorthEastSouthWest, new String[]
						{
							"neResizeRegion", "swResizeRegion"
		});
		JAVA_CLASS_DATA_FORMAT = new DataFormat("application/x-java-class");
	}

	private final boolean isRoot;

	public CTView(URL fxml, ControlTree t, DesignerMetadata infl)
	{
		this(fxml, t, infl, false);
	}

	public CTView(URL fxml, ControlTree t, DesignerMetadata infl, boolean isRoot)
	{
		this.isRoot = isRoot;
		tree = t;
		meta = infl;
		FXMLLoader fxmlLoader = new FXMLLoader(fxml);
		fxmlLoader.setRoot(this);
		fxmlLoader.setController(this);

		try
		{
			fxmlLoader.load();
		}
		catch (IOException exception)
		{
			throw new RuntimeException(exception);
		}
	}

	/**
	 * Called by metadata builder
	 */
	void init()
	{
		// TODO: test
		tree.controlTypeProperty().addListener((ov, old, t1) -> resetChild());
		resetChild();
		// TODO: test
	/*	t.getProperties().addListener((MapChangeListener.Change<? extends String, ? extends Object> change) -> {
		 // TODO: check to see if the node is here to avoid dropping values
		 if (!change.wasRemoved())
		 {
		 inflator.setProperty(change.getKey(), change.getValueAdded(), childContainer.getCenter());
		 }
		 else
		 {
		 inflator.resetProperty(change.getKey(), childContainer.getCenter());
		 }
		 });*/
		selected_ui.visibleProperty().bind(editing_nested.not());
		BooleanBinding selectedProp = meta.selectedProperty().isEqualTo(tree);
		selected_ui.opacityProperty().bind(
				Bindings.createDoubleBinding(() -> (selectedProp.get()?1.0:0.0), selectedProp));
		meta.editingProperty().addListener((ov, old, nv) -> editingChanged(nv));
		editingChanged(meta.getEditing());
	}

	private ShapeInversionBinding area;

	private void initOverlay(CTView ctv)
	{
		area = new ShapeInversionBinding(this.boundsInLocalProperty(), ctv.boundsInParentProperty(), ctv);
		area.addListener((a, b, node) ->
		{
			if (allow == false)
			{
				return;
			}
			allow = false;
			GridPane.setColumnSpan(node, REMAINING);
			GridPane.setRowSpan(node, REMAINING);
			GridPane.setHgrow(node, Priority.ALWAYS);
			GridPane.setVgrow(node, Priority.ALWAYS);
			if (ssn != null && node.toString().equals(ssn.toString()))
			{
				allow = true;
				return;
			}
			if (ssn != null)
			{
				this.getChildren().remove(ssn);
				node.setVisible(ssn.isVisible());
			}
			else
			{
				node.setVisible(ssnVisible);
			}
			ssn = node;
			this.getChildren().add(node);
			allow = true;
		});
	}

	private void resetParentOptions()
	{
		/*   sops = @parent.getSupportedOps
		 @supported_ops = RESIZABILITY_MAPPER.map do |key, cor|
		 if sops.contains(key)
		 cor
		 else
		 cor.each {|c| self.instance_variable_get("@#{c}").opacity = 0}
		 []
		 end
		 end.flatten
		 @child.registered(prov)*/
	}

	private SimpleBooleanProperty editing_nested = new SimpleBooleanProperty(false);

	private void becomeRoot()
	{
		//fx:id="groupMax" GridPane.columnIndex="1" GridPane.halignment="CENTER" GridPane.hgrow="ALWAYS" GridPane.rowIndex="1" GridPane.valignment="CENTER" GridPane.vgrow="ALWAYS">
		this.getChildren().clear();
		Node node = child.getUi();
		this.getChildren().add(node);
		GridPane.setColumnSpan(node, REMAINING);
		GridPane.setRowSpan(node, REMAINING);
		GridPane.setHgrow(node, Priority.ALWAYS);
		GridPane.setVgrow(node, Priority.ALWAYS);
		enterEdit();
	}

	public void enterEdit()
	{
		editing_nested.set(true);
	}

	public void exitEdit()
	{
		editing_nested.set(false);
	}

	private void resetChild()
	{
		if (future != null && !future.isDone())
		{
			future.cancel(true);
		}
		future = meta.getInflator().inflate(tree.getControlType(), tree.getProperties());
		future.thenAccept((n) ->
		{
			child = n;
			childContainer.setCenter(n.getUi());
			if (isRoot)
			{
				// TODO: hack
				child.getUi().setStyle("");
				becomeRoot();
			}
			// TODO: Children
		});
	}

	@FXML
	void on_drag_dropped(DragEvent event)
	{
		if (event.isDropCompleted())
		{
			return;
		}
		Dragboard db = event.getDragboard();
		try
		{
			ControlMetaInfo x = (ControlMetaInfo) db.getContent(JAVA_CLASS_DATA_FORMAT);
			//ControlMetaInfo x = _RawSlider_68e6317cc.class.newInstance();
			addClass(x, event.getX(), event.getY());
		}
		catch (Throwable ex)
		{
			ex.printStackTrace();
			System.err.println("Could not create class instance from dropped control");
		}
		event.setDropCompleted(true);
		event.consume();
	}

	@FXML
	void on_drag_over(DragEvent event)
	{
		if (event.getDragboard().hasContent(JAVA_CLASS_DATA_FORMAT))
		{
			// TODO: figure out childing rules and clean this up
			if (child != null && (child instanceof DesignablePane || child.getUiChildren() != null))
			{
				event.acceptTransferModes(TransferMode.COPY);
			}
		}
	}

	private void addClass(ControlMetaInfo cname, double x, double y)
	{

		ControlTree lTree = meta.newNode(tree, cname);
		// TODO: should probbably use observable list of children somehow, but then we loose the xy
		CTView ctv = meta.getAssociatedView(lTree);
		if (child instanceof DesignablePane)
		{
			DesignablePane pane = (DesignablePane) child;
			pane.addChildAt(ctv, x, y);
		}
		else
		{
			if (child.getUiChildren() != null)
			{
				child.getUiChildren().add(ctv);
			}
		}
	}
	boolean allow = true;
	boolean ssnVisible = false;
	Shape ssn = null;

	/**
	 * Class used to compute the difference between two rectangles (the outer
	 * minus the inner) as used for nested editing
	 */
	public class ShapeInversionBinding extends ObjectBinding<Shape>
	{

		private ObservableValue<Bounds> in;
		private final ObservableValue<Bounds> out;
		private CTView child;

		public ShapeInversionBinding(ObservableValue<Bounds> out, ObservableValue<Bounds> in, CTView child)
		{
			this.out = out;
			this.in = in;
			this.child = child;
			bind(out, in);
		}

		public void setChild(ObservableValue<Bounds> in, CTView child)
		{
			unbind(this.in);
			this.in = in;
			this.child = child;
			bind(in);
		}

		@Override
		protected Shape computeValue()
		{
			Rectangle r = new Rectangle(out.getValue().getWidth() - 1, out.getValue().getHeight() - 1);
			Bounds ib = sceneToLocal(child.localToScene(child.getBoundsInLocal()));
			Rectangle in = new Rectangle(ib.getMinX(), ib.getMinY(), ib.getWidth(), ib.getHeight());
			Shape s = Shape.subtract(r, in);
			s.setFill(Color.grayRgb(128, 0.3));
			return s;
		}
	}
}
