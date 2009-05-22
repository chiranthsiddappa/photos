
public class PageMarker {
    public Gtk.Widget notebook_page;
    private Gtk.TreeRowReference row = null;
    
    public PageMarker(Gtk.Widget notebook_page, Gtk.TreeModel? model = null, Gtk.TreePath? path = null ) {
        this.notebook_page = notebook_page;
        if ((model != null) && (path != null))
            this.row = new Gtk.TreeRowReference(model, path);
    }
    
    public unowned Gtk.TreeRowReference get_row() {
        return row;
    }
}

public abstract class Page : Gtk.ScrolledWindow {
    public static const uint KEY_CTRL_L = Gdk.keyval_from_name("Control_L");
    public static const uint KEY_CTRL_R = Gdk.keyval_from_name("Control_R");
    public static const uint KEY_ALT_L = Gdk.keyval_from_name("Alt_L");
    public static const uint KEY_ALT_R = Gdk.keyval_from_name("Alt_R");
    
    public static const string STOCK_CLOCKWISE = "shotwell-rotate-clockwise";
    public static const string STOCK_COUNTERCLOCKWISE = "shotwell-rotate-counterclockwise";
    
    public static const Gdk.Color BG_COLOR = parse_color("#777");

    private static Gtk.IconFactory factory = null;
    
    private static void addStockIcon(File file, string stockID) {
        debug("Adding icon %s", file.get_path());
        
        Gdk.Pixbuf pixbuf = null;
        try {
            pixbuf = new Gdk.Pixbuf.from_file(file.get_path());
        } catch (Error err) {
            error("%s", err.message);
        }
        
        Gtk.IconSet iconSet = new Gtk.IconSet.from_pixbuf(pixbuf);
        factory.add(stockID, iconSet);
    }
    
    private static void prepIcons() {
        if (factory != null)
            return;
        
        factory = new Gtk.IconFactory();
        
        File icons_dir = AppWindow.get_ui_dir().get_child("icons");
        addStockIcon(icons_dir.get_child("object-rotate-right.svg"), STOCK_CLOCKWISE);
        addStockIcon(icons_dir.get_child("object-rotate-left.svg"), STOCK_COUNTERCLOCKWISE);
        
        factory.add_default();
    }
    
    public Gtk.UIManager ui = new Gtk.UIManager();
    public Gtk.ActionGroup action_group = null;
    public Gtk.MenuBar menu_bar = null;
    public PageMarker marker = null;
    
    public Page() {
        prepIcons();
        
        button_press_event += on_click;
        AppWindow.get_instance().key_press_event += on_key_pressed_internal;
        AppWindow.get_instance().key_release_event += on_key_released_internal;
        AppWindow.get_instance().configure_event += on_configure;
    }
    
    public void set_marker(PageMarker marker) {
        this.marker = marker;
    }
    
    public PageMarker get_marker() {
        return marker;
    }
    
    public virtual Gtk.MenuBar get_menubar() {
        return menu_bar;
    }

    public abstract Gtk.Toolbar get_toolbar();
    
    public virtual void switching_from() {
    }
    
    public virtual void switched_to() {
    }
    
    public virtual void switching_to_fullscreen() {
    }
    
    public virtual void returning_from_fullscreen() {
    }
    
    public void set_item_sensitive(string path, bool sensitive) {
        ui.get_widget(path).sensitive = sensitive;
    }
    
    protected virtual bool on_left_click(Gdk.EventButton event) {
        return false;
    }
    
    protected virtual bool on_middle_click(Gdk.EventButton event) {
        return false;
    }
    
    protected virtual bool on_right_click(Gdk.EventButton event) {
        return false;
    }
    
    protected void init_ui(string ui_filename, string? menubar_path, string action_group_name, 
        Gtk.ActionEntry[]? entries = null, Gtk.ToggleActionEntry[]? toggle_entries = null) {
        init_ui_start(ui_filename, action_group_name, entries, toggle_entries);
        init_ui_bind(menubar_path);
    }
    
    protected void init_load_ui(string ui_filename) {
        File ui_file = AppWindow.get_ui_dir().get_child(ui_filename);

        try {
            ui.add_ui_from_file(ui_file.get_path());
        } catch (Error gle) {
            error("Error loading UI file %s: %s", ui_filename, gle.message);
        }
    }
    
    protected void init_ui_start(string ui_filename, string action_group_name,
        Gtk.ActionEntry[]? entries = null, Gtk.ToggleActionEntry[]? toggle_entries = null) {
        init_load_ui(ui_filename);

        action_group = new Gtk.ActionGroup(action_group_name);
        if (entries != null)
            action_group.add_actions(entries, this);
        if (toggle_entries != null)
            action_group.add_toggle_actions(toggle_entries, this);
    }
    
    protected void init_ui_bind(string? menubar_path) {
        ui.insert_action_group(action_group, 0);
        ui.insert_action_group(AppWindow.get_instance().get_common_action_group(), 0);
        
        if (menubar_path != null)
            menu_bar = (Gtk.MenuBar) ui.get_widget(menubar_path);

        ui.ensure_update();
    }
    
    private bool on_click(Page p, Gdk.EventButton event) {
        switch (event.button) {
            case 1:
                return on_left_click(event);
            
            case 2:
                return on_middle_click(event);
            
            case 3:
                return on_right_click(event);
            
            default:
                return false;
        }
    }

    protected virtual bool on_key_pressed(Gdk.EventKey event) {
        return false;
    }
    
    protected virtual bool on_key_released(Gdk.EventKey event) {
        return false;
    }
    
    protected virtual bool on_ctrl_pressed(Gdk.EventKey event) {
        return false;
    }
    
    protected virtual bool on_ctrl_released(Gdk.EventKey event) {
        return false;
    }
    
    protected virtual bool on_alt_pressed(Gdk.EventKey event) {
        return false;
    }
    
    protected virtual bool on_alt_released(Gdk.EventKey event) {
        return false;
    }
    
    protected virtual bool on_resize(Gdk.Rectangle rect) {
        return false;
    }
    
    private bool on_key_pressed_internal(AppWindow aw, Gdk.EventKey event) {
        if ((event.keyval == KEY_CTRL_L) || (event.keyval == KEY_CTRL_R)) {
            return on_ctrl_pressed(event);
        }
        
        if ((event.keyval == KEY_ALT_L) || (event.keyval == KEY_ALT_R)) {
            return on_alt_pressed(event);
        }

        return on_key_pressed(event);
    }
    
    private bool on_key_released_internal(AppWindow aw, Gdk.EventKey event) {
        if ((event.keyval == KEY_CTRL_L) || (event.keyval == KEY_CTRL_R)) {
            return on_ctrl_released(event);
        }
        
        if ((event.keyval == KEY_ALT_L) || (event.keyval == KEY_ALT_R)) {
            return on_alt_released(event);
        }

        return on_key_released(event);
    }
    
    private bool on_configure(AppWindow aw, Gdk.EventConfigure event) {
        Gdk.Rectangle rect = Gdk.Rectangle();
        rect.x = event.x;
        rect.y = event.y;
        rect.width = event.width;
        rect.height = event.height;
        
        return on_resize(rect);
    }
}

public abstract class CheckerboardPage : Page {
    private Gtk.Menu context_menu = null;
    private CollectionLayout layout = new CollectionLayout();
    private Gee.HashSet<LayoutItem> selected_items = new Gee.HashSet<LayoutItem>();
    private string page_name = null;
    
    public CheckerboardPage(string page_name) {
        this.page_name = page_name;
        
        add(layout);
    }
    
    public virtual string get_name() {
        return page_name;
    }
    
    public void init_context_menu(string path) {
        context_menu = (Gtk.Menu) ui.get_widget(path);
    }
    
    protected virtual void on_selection_changed(int count) {
    }
    
    public virtual Gtk.Menu? get_context_menu(LayoutItem? item) {
        return (item != null) ? context_menu : null;
    }
    
    protected virtual void on_item_activated(LayoutItem item) {
    }
    
    protected virtual bool on_context_invoked(Gtk.Menu context_menu) {
        return true;
    }
    
    public abstract LayoutItem? get_fullscreen_photo();
    
    public void refresh() {
        show_all();
        layout.refresh();
    }
    
    public void set_page_message(string message) {
        layout.set_message(message);
    }
    
    public void set_refresh_on_resize(bool refresh_on_resize) {
        layout.set_refresh_on_resize(refresh_on_resize);
    }
    
    public void set_layout_comparator(Comparator<LayoutItem> cmp) {
        layout.set_comparator(cmp);
    }
    
    public LayoutItem? get_item_at(double x, double y) {
        return layout.get_item_at(x, y);
    }
    
    public Gee.Iterable<LayoutItem> get_items() {
        return layout.items;
    }
    
    public Gee.Iterable<LayoutItem> get_selected() {
        return selected_items;
    }
    
    public void add_item(LayoutItem item) {
        layout.add_item(item);
    }
    
    public void remove_item(LayoutItem item) {
        selected_items.remove(item);
        layout.remove_item(item);
    }
    
    public int remove_selected() {
        int count = selected_items.size;
        
        foreach (LayoutItem item in selected_items)
            layout.remove_item(item);
        
        selected_items.clear();
        
        return count;
    }
    
    public int remove_all() {
        int count = layout.items.size;
        
        layout.clear();
        selected_items.clear();
        
        return count;
    }
    
    public int get_count() {
        return layout.items.size;
    }
    
    public void select_all() {
        foreach (LayoutItem item in layout.items) {
            selected_items.add(item);
            item.select();
        }
        
        on_selection_changed(selected_items.size);
    }

    public void unselect_all() {
        foreach (LayoutItem item in selected_items) {
            assert(item.is_selected());
            item.unselect();
        }
        
        selected_items.clear();
        
        on_selection_changed(0);
    }

    public void select(LayoutItem item) {
        assert(layout.items.index_of(item) >= 0);
        
        item.select();
        selected_items.add(item);
        
        on_selection_changed(selected_items.size);
    }
    
    public void unselect(LayoutItem item) {
        assert(layout.items.index_of(item) >= 0);
        
        item.unselect();
        selected_items.remove(item);
        
        on_selection_changed(selected_items.size);
    }

    public void toggle_select(LayoutItem item) {
        if (item.toggle_select()) {
            // now selected
            selected_items.add(item);
        } else {
            // now unselected
            selected_items.remove(item);
        }
        
        on_selection_changed(selected_items.size);
    }

    public int get_selected_count() {
        return selected_items.size;
    }

    private override bool on_left_click(Gdk.EventButton event) {
        // only interested in single-click and double-clicks for now
        if ((event.type != Gdk.EventType.BUTTON_PRESS) 
            && (event.type != Gdk.EventType.2BUTTON_PRESS)) {
            return false;
        }
        
        // mask out the modifiers we're interested in
        uint state = event.state & (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK);
        
        LayoutItem item = get_item_at(event.x, event.y);
        if (item != null) {
            switch (state) {
                case Gdk.ModifierType.CONTROL_MASK: {
                    // with only Ctrl pressed, multiple selections are possible ... chosen item
                    // is toggled
                    toggle_select(item);
                } break;
                
                case Gdk.ModifierType.SHIFT_MASK: {
                    // TODO
                } break;
                
                case Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK: {
                    // TODO
                } break;
                
                default: {
                    if (event.type == Gdk.EventType.2BUTTON_PRESS) {
                        on_item_activated(item);
                    } else {
                        // a "raw" single-click deselects all thumbnails and selects the single chosen
                        unselect_all();
                        select(item);
                    }
                } break;
            }
        } else {
            // user clicked on "dead" area
            unselect_all();
        }

        return true;
    }
    
    private override bool on_right_click(Gdk.EventButton event) {
        // only interested in single-clicks for now
        if (event.type != Gdk.EventType.BUTTON_PRESS) {
            return false;
        }
        
        LayoutItem item = get_item_at(event.x, event.y);
        if (item != null) {
            // TODO: Enable context menus for multiple and single selections
            unselect_all();
            select(item);
        }
            
        Gtk.Menu context_menu = get_context_menu(item);
        if (context_menu != null) {
            if (!on_context_invoked(context_menu))
                return false;
            
            context_menu.popup(null, null, null, event.button, event.time);

            return true;
        }
            
        return false;
    }
    
    public LayoutItem? get_next_item(LayoutItem current) {
        if (layout.items.size == 0)
            return null;
        
        int index = layout.items.index_of(current);

        // although items may be added while the page is away, not handling situations where an active
        // item is removed
        assert(index >= 0);

        index++;
        if (index >= layout.items.size)
            index = 0;
        
        return layout.items.get(index);
    }
    
    public LayoutItem? get_previous_item(LayoutItem current) {
        if (layout.items.size == 0)
            return null;
        
        int index = layout.items.index_of(current);
        
        // although items may be added while the page is away, not handling situations where an active
        // item is removed
        assert(index >= 0);

        index--;
        if (index < 0)
            index = (layout.items.size - 1);
        
        return layout.items.get(index);
    }
}
