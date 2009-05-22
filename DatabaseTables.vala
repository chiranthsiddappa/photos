
public struct DatabaseID {
    public static const int64 INVALID = 0;

    public int64 id;
    
    public DatabaseID(int64 id = INVALID) {
        this.id = id;
    }
    
    public bool is_invalid() {
        return (id == INVALID);
    }
    
    public bool is_valid() {
        return (id != INVALID);
    }
}

public class DatabaseTable : Object {
    protected static Sqlite.Database db;

    // Doing this because static construct {} not working
    public static void init() {
        File dbFile = AppWindow.get_data_subdir("data").get_child("photo.db");
        int res = Sqlite.Database.open_v2(dbFile.get_path(), out db, 
            Sqlite.OPEN_READWRITE | Sqlite.OPEN_CREATE, null);
        if (res != Sqlite.OK) {
            error("Unable to open/create photo database %s: %d", dbFile.get_path(), res);
        }
    }
    
    public static void terminate() {
    }
    
    // TODO: errmsg() is global, and so this will not be accurate in a threaded situation
    protected static void fatal(string op, int res) {
        error("%s: [%d] %s", op, res, db.errmsg());
    }
    
    // TODO: errmsg() is global, and so this will not be accurate in a threaded situation
    protected static void warning(string op, int res) {
        GLib.warning("%s: [%d] %s", op, res, db.errmsg());
    }
}

public struct PhotoID {
    public static const int64 INVALID = -1;

    public int64 id;
    
    public PhotoID(int64 id = INVALID) {
        this.id = id;
    }
    
    public bool is_invalid() {
        return (id == INVALID);
    }
    
    public bool is_valid() {
        return (id != INVALID);
    }
}

public struct ImportID {
    public static const int64 INVALID = -1;

    public int64 id;
    
    public ImportID(int64 id = INVALID) {
        this.id = id;
    }
    
    public bool is_invalid() {
        return (id == INVALID);
    }
    
    public bool is_valid() {
        return (id != INVALID);
    }
}

public class PhotoTable : DatabaseTable {
    public PhotoTable() {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("CREATE TABLE IF NOT EXISTS PhotoTable ("
            + "id INTEGER PRIMARY KEY, "
            + "filename TEXT UNIQUE NOT NULL, "
            + "width INTEGER, "
            + "height INTEGER, "
            + "filesize INTEGER, "
            + "timestamp INTEGER, "
            + "exposure_time INTEGER, "
            + "orientation INTEGER, "
            + "original_orientation INTEGER, "
            + "import_id INTEGER, "
            + "event_id INTEGER, "
            + "transformations TEXT"
            + ")", -1, out stmt);
        assert(res == Sqlite.OK);

        res = stmt.step();
        if (res != Sqlite.DONE) {
            fatal("create photo table", res);
        }
    }
    
    public ImportID generate_import_id() {
        // TODO: Use a guid here?  Key here is that last imported photos can be easily identified
        // by finding the largest value in the PhotoTable
        TimeVal timestamp = TimeVal();
        timestamp.get_current_time();
        int64 id = timestamp.tv_sec;
        
        return ImportID(id);
    }
    
    public PhotoID add(File file, Dimensions dim, int64 filesize, long timestamp, time_t exposure_time,
        Orientation orientation, ImportID import_id) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2(
            "INSERT INTO PhotoTable (filename, width, height, filesize, timestamp, exposure_time, orientation, original_orientation, import_id, event_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            -1, out stmt);
        assert(res == Sqlite.OK);
        
        debug("Import %s %dx%d size=%lld mod=%ld exp=%ld or=%d", file.get_path(), dim.width, dim.height,
            filesize, timestamp, exposure_time, (int) orientation);

        res = stmt.bind_text(1, file.get_path());
        assert(res == Sqlite.OK);
        res = stmt.bind_int(2, dim.width);
        assert(res == Sqlite.OK);
        res = stmt.bind_int(3, dim.height);
        assert(res == Sqlite.OK);
        res = stmt.bind_int64(4, filesize);
        assert(res == Sqlite.OK);
        res = stmt.bind_int64(5, timestamp);
        assert(res == Sqlite.OK);
        res = stmt.bind_int64(6, exposure_time);
        assert(res == Sqlite.OK);
        res = stmt.bind_int(7, orientation);
        assert(res == Sqlite.OK);
        res = stmt.bind_int(8, orientation);
        assert(res == Sqlite.OK);
        res = stmt.bind_int64(9, import_id.id);
        assert(res == Sqlite.OK);
        res = stmt.bind_int64(10, PhotoID.INVALID);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.DONE) {
            if (res != Sqlite.CONSTRAINT)
                fatal("add_photo", res);
            
            return PhotoID();
        }

        return PhotoID(db.last_insert_rowid());
    }
    
    public bool update(PhotoID photoID, Dimensions dim, int64 filesize, long timestamp, 
        time_t exposure_time, Orientation orientation) {
        
        Sqlite.Statement stmt;
        int res = db.prepare_v2(
            "UPDATE PhotoTable SET width = ?, height = ?, filesize = ?, timestamp = ?, "
            + "exposure_time = ?, orientation = ?, original_orientation = ? WHERE id = ?", -1, out stmt);
        assert(res == Sqlite.OK);
        
        debug("Update [%lld] %dx%d size=%lld mod=%ld exp=%ld or=%d", photoID.id, dim.width, 
            dim.height, filesize, timestamp, exposure_time, (int) orientation);

        res = stmt.bind_int(1, dim.width);
        assert(res == Sqlite.OK);
        res = stmt.bind_int(2, dim.height);
        assert(res == Sqlite.OK);
        res = stmt.bind_int64(3, filesize);
        assert(res == Sqlite.OK);
        res = stmt.bind_int64(4, timestamp);
        assert(res == Sqlite.OK);
        res = stmt.bind_int64(5, exposure_time);
        assert(res == Sqlite.OK);
        res = stmt.bind_int(6, orientation);
        assert(res == Sqlite.OK);
        res = stmt.bind_int(7, orientation);
        assert(res == Sqlite.OK);
        res = stmt.bind_int64(7, photoID.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.DONE) {
            if (res != Sqlite.CONSTRAINT)
                fatal("update_photo", res);
            
            return false;
        }

        return true;
    }
    
    public bool exists(PhotoID photo_id) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("SELECT id FROM PhotoTable WHERE id=?", -1, out stmt);
        assert(res == Sqlite.OK);
        
        res = stmt.bind_int64(1, photo_id.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        
        return (res == Sqlite.ROW);
    }

    public bool get_photo(PhotoID photoID, out PhotoRow row) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("SELECT filename, width, height, filesize, timestamp, exposure_time, orientation, original_orientation, import_id, event_id FROM PhotoTable WHERE id=?", -1, out stmt);
        assert(res == Sqlite.OK);
        
        res = stmt.bind_int64(1, photoID.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.ROW)
            return false;
        
        row.photo_id = photoID;
        row.file = File.new_for_path(stmt.column_text(0));
        row.dim = Dimensions(stmt.column_int(1), stmt.column_int(2));
        row.filesize = stmt.column_int64(3);
        row.timestamp = (long) stmt.column_int64(4);
        row.exposure_time = (long) stmt.column_int64(5);
        row.orientation = (Orientation) stmt.column_int(6);
        row.original_orientation = (Orientation) stmt.column_int(7);
        row.import_id = ImportID(stmt.column_int64(8));
        row.event_id = EventID(stmt.column_int64(9));
        
        return true;
    }

    public File? get_file(PhotoID photoID) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("SELECT filename FROM PhotoTable WHERE id=?", -1, out stmt);
        assert(res == Sqlite.OK);
        
        res = stmt.bind_int64(1, photoID.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res == Sqlite.ROW)
            return File.new_for_path(stmt.column_text(0));
        
        return null;
    }
    
    public time_t get_exposure_time(PhotoID photoID) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("SELECT exposure_time FROM PhotoTable WHERE id=?", -1, out stmt);
        assert(res == Sqlite.OK);
        
        res = stmt.bind_int64(1, photoID.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.ROW)
            return 0;
        
        return (time_t) stmt.column_int64(0);
    }
    
    public bool remove_by_file(File file) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("DELETE FROM PhotoTable WHERE filename=?", -1, out stmt);
        assert(res == Sqlite.OK);

        res = stmt.bind_text(1, file.get_path());
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.DONE) {
            warning("remove", res);
            
            return false;
        }
        
        return true;
    }
    
    public bool remove(PhotoID photoID) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("DELETE FROM PhotoTable WHERE id=?", -1, out stmt);
        assert(res == Sqlite.OK);

        res = stmt.bind_int64(1, photoID.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.DONE) {
            warning("remove", res);
            
            return false;
        }
        
        return true;
    }
    
    public bool is_photo_stored(File file) {
        return (get_id(file).is_invalid() == false);
    }
    
    public PhotoID get_id(File file) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("SELECT ID FROM PhotoTable WHERE filename=?", -1, out stmt);
        assert(res == Sqlite.OK);

        res = stmt.bind_text(1, file.get_path());
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if(res != Sqlite.ROW) {
            warning("get_photo_id", res);

            return PhotoID();
        }
        
        return PhotoID(stmt.column_int64(0));
    }

    public PhotoID[] get_photos() {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("SELECT id FROM PhotoTable", -1, out stmt);
        assert(res == Sqlite.OK);

        PhotoID[] photoIds = new PhotoID[0];
        for (;;) {
            res = stmt.step();
            if (res == Sqlite.DONE) {
                break;
            } else if (res != Sqlite.ROW) {
                fatal("get_photo_ids", res);

                break;
            }
            
            photoIds += PhotoID(stmt.column_int64(0));
        }
        
        return photoIds;
    }
    
    public Dimensions? get_dimensions(PhotoID photoID) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("SELECT width, height FROM PhotoTable WHERE id=?", -1, out stmt);
        assert(res == Sqlite.OK);
        
        res = stmt.bind_int64(1, photoID.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.ROW) {
            if (res != Sqlite.DONE) {
                fatal("get_dimensions", res);
            }
            
            return null;
        }
        
        return Dimensions(stmt.column_int(0), stmt.column_int(1));
    }
    
    public Orientation get_original_orientation(PhotoID photo_id) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("SELECT original_orientation FROM PhotoTable WHERE id=?", -1, out stmt);
        assert(res == Sqlite.OK);
        
        res = stmt.bind_int64(1, photo_id.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.ROW) {
            if (res != Sqlite.DONE) {
                fatal("get_original_orientation", res);
            }

            return Orientation.TOP_LEFT;
        }
    
        return (Orientation) stmt.column_int(0);
    }
    
    public Orientation get_orientation(PhotoID photo_id) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("SELECT orientation FROM PhotoTable WHERE id=?", -1, out stmt);
        assert(res == Sqlite.OK);
        
        res = stmt.bind_int64(1, photo_id.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.ROW) {
            if (res != Sqlite.DONE) {
                fatal("get_orientation", res);
            }

            return Orientation.TOP_LEFT;
        }
    
        return (Orientation) stmt.column_int(0);
    }
    
    public bool set_orientation(PhotoID photo_id, Orientation orientation) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("UPDATE PhotoTable SET orientation = ? WHERE id = ?", -1, out stmt);
        assert(res == Sqlite.OK);
        
        res = stmt.bind_int(1, (int) orientation);
        assert(res == Sqlite.OK);
        res = stmt.bind_int64(2, photo_id.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.DONE) { 
            fatal("photo set_orientation", res);
            
            return false;
        }
        
        return true;
    }

    public EventID get_event(PhotoID photo_id) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("SELECT event_id FROM PhotoTable WHERE id=?", -1, out stmt);
        assert(res == Sqlite.OK);
        
        res = stmt.bind_int64(1, photo_id.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.ROW) {
            if (res != Sqlite.DONE) {
                fatal("get_event", res);
            }

            return EventID();
        }
    
        return EventID(stmt.column_int(0));
    }
    
    public PhotoID[] get_event_photos(EventID event_id) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("SELECT id FROM PhotoTable WHERE event_id = ?", -1, out stmt);
        assert(res == Sqlite.OK);
        
        res = stmt.bind_int64(1, event_id.id);
        assert(res == Sqlite.OK);
        
        PhotoID[] photos = new PhotoID[0];
        for(;;) {
            res = stmt.step();
            if (res == Sqlite.DONE) {
                break;
            } else if (res != Sqlite.ROW) {
                fatal("get_event_photos", res);

                break;
            }
            
            photos += PhotoID(stmt.column_int64(0));
        }
        
        return photos;
    }
    
    public bool set_event(PhotoID photo_id, EventID event_id) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("UPDATE PhotoTable SET event_id = ? WHERE id = ?", -1, out stmt);
        assert(res == Sqlite.OK);
        
        res = stmt.bind_int64(1, event_id.id);
        assert(res == Sqlite.OK);
        res = stmt.bind_int64(2, photo_id.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.DONE) { 
            fatal("set_event", res);
            
            return false;
        }
        
        return true;
    }
    
    private string? get_raw_transformations(PhotoID photo_id) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("SELECT transformations FROM PhotoTable WHERE id=?", -1, out stmt);
        assert(res == Sqlite.OK);
        
        res = stmt.bind_int64(1, photo_id.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.ROW) {
            if (res != Sqlite.DONE) {
                fatal("get_raw_transformations", res);
            }

            return null;
        }
    
        string trans = stmt.column_text(0);
        if (trans != null && trans.length == 0)
            trans = null;
        
        return trans;
    }
    
    private bool set_raw_transformations(PhotoID photo_id, string trans) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("UPDATE PhotoTable SET transformations = ? WHERE id = ?", -1, out stmt);
        assert(res == Sqlite.OK);
        
        res = stmt.bind_text(1, trans);
        assert(res == Sqlite.OK);
        res = stmt.bind_int64(2, photo_id.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.DONE) { 
            fatal("set_raw_transformations", res);
            
            return false;
        }
        
        return true;
    }
    
    public bool has_transformations(PhotoID photo_id) {
        return get_raw_transformations(photo_id) != null;
    }
    
    public KeyValueMap? get_transformation(PhotoID photo_id, string object) {
        string trans = get_raw_transformations(photo_id);
        if (trans == null)
            return null;
            
        try {
            KeyFile keyfile = new KeyFile();
            if (!keyfile.load_from_data(trans, trans.length, KeyFileFlags.NONE))
                return null;
                
            string[] keys = keyfile.get_keys(object);
            if (keys == null || keys.length == 0)
                return null;

            KeyValueMap map = new KeyValueMap(object);
            foreach (string key in keys)
                map.set_string(key, keyfile.get_string(object, key));
            
            return map;
        } catch (Error err) {
            error("%s", err.message);
            
            return null;
        }
    }
    
    public bool set_transformation(PhotoID photo_id, KeyValueMap map) {
        string trans = get_raw_transformations(photo_id);
        
        try {
            KeyFile keyfile = new KeyFile();
            if (trans != null) {
                if (!keyfile.load_from_data(trans, trans.length, KeyFileFlags.NONE))
                    return false;
            }
            
            Gee.Set<string> keys = map.get_keys();
            foreach (string key in keys) {
                string value = map.get_string(key, null);
                assert(value != null);
                
                keyfile.set_string(map.get_group(), key, value);
            }
            
            int length;
            trans = keyfile.to_data(out length);
            assert(trans != null);
            assert(trans.length > 0);
        } catch (Error err) {
            error("%s", err.message);
            
            return false;
        }
        
        return set_raw_transformations(photo_id, trans);
    }
    
    public bool remove_transformation(PhotoID photo_id, string object) {
        string trans = get_raw_transformations(photo_id);
        if (trans == null)
            return true;
        
        try {
            KeyFile keyfile = new KeyFile();
            if (!keyfile.load_from_data(trans, trans.length, KeyFileFlags.NONE))
                return false;
            
            keyfile.remove_group(object);
            
            int length;
            trans = keyfile.to_data(out length);
            assert(trans != null);
        } catch (Error err) {
            error("%s", err.message);
            
            return false;
        }
        
        return set_raw_transformations(photo_id, trans);
    }
    
    public bool remove_all_transformations(PhotoID photo_id) {
        if (get_raw_transformations(photo_id) == null)
            return false;
            
        Sqlite.Statement stmt;
        int res = db.prepare_v2("UPDATE PhotoTable SET transformations='' WHERE id=?", -1, out stmt);
        assert(res == Sqlite.OK);
        
        res = stmt.bind_int64(1, photo_id.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.DONE) {
            fatal("remove_all_transformations", res);
            
            return false;
        }
        
        return true;
    }
}

public class ThumbnailCacheTable : DatabaseTable {
    private string table_name;
    
    public ThumbnailCacheTable(int scale) {
        assert(scale > 0);

        this.table_name = "Thumb%dTable".printf(scale);
        
        Sqlite.Statement stmt;
        int res = db.prepare_v2("CREATE TABLE IF NOT EXISTS "
            + table_name
            + "("
            + "id INTEGER PRIMARY KEY, "
            + "photo_id INTEGER UNIQUE, "
            + "width INTEGER, "
            + "height INTEGER, "
            + "filesize INTEGER"
            + ")", -1, out stmt);
        assert(res == Sqlite.OK);

        res = stmt.step();
        if (res != Sqlite.DONE) {
            fatal("create %s".printf(table_name), res);
        }
    }
    
    public bool remove(PhotoID photo_id) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("DELETE FROM %s WHERE photo_id=?".printf(table_name), -1, out stmt);
        assert(res == Sqlite.OK);

        res = stmt.bind_int64(1, photo_id.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.DONE) {
            warning("%s remove".printf(table_name), res);

            return false;
        }
        
        return true;
    }
    
    public bool exists(PhotoID photo_id) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("SELECT id FROM %s WHERE photo_id=?".printf(table_name), -1, out stmt);
        assert(res == Sqlite.OK);

        res = stmt.bind_int64(1, photo_id.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.ROW) {
            if (res != Sqlite.DONE) {
                fatal("%s exists".printf(table_name), res);
            }
            
            return false;
        }
        
        return true;
    }
    
    public void add(PhotoID photo_id, int filesize, Dimensions dim) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2(
            "INSERT INTO %s (photo_id, filesize, width, height) VALUES (?, ?, ?, ?)".printf(table_name),
            -1, out stmt);
        assert(res == Sqlite.OK);

        res = stmt.bind_int64(1, photo_id.id);
        assert(res == Sqlite.OK);
        res = stmt.bind_int(2, filesize);
        assert(res == Sqlite.OK);
        stmt.bind_int(3, dim.width);
        assert(res == Sqlite.OK);
        res = stmt.bind_int(4, dim.height);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.DONE) {
            fatal("%s add".printf(table_name), res);
        }
    }
    
    public void replace(PhotoID photo_id, int filesize, Dimensions dim) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2(
            "UPDATE %s SET filesize=?, width=?, height=? WHERE photo_id=?".printf(table_name),
            -1, out stmt);
        assert(res == Sqlite.OK);
        
        res = stmt.bind_int(1, filesize);
        assert(res == Sqlite.OK);
        res = stmt.bind_int(2, dim.width);
        assert(res == Sqlite.OK);
        res = stmt.bind_int(3, dim.height);
        assert(res == Sqlite.OK);
        res = stmt.bind_int64(4, photo_id.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.DONE)
            fatal("%s replace".printf(table_name), res);
    }
    
    public Dimensions? get_dimensions(PhotoID photo_id) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("SELECT width, height FROM %s WHERE photo_id=?".printf(table_name), 
            -1, out stmt);
        assert(res == Sqlite.OK);

        res = stmt.bind_int64(1, photo_id.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.ROW) {
            if(res != Sqlite.DONE) {
                fatal("%s get_dimensions".printf(table_name), res);
            }

            return null;
        }
        
        return Dimensions(stmt.column_int(0), stmt.column_int(1));
    }
    
    public int get_filesize(PhotoID photoID) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("SELECT filesize FROM %s WHERE photo_id=?".printf(table_name),
            -1, out stmt);
        assert(res == Sqlite.OK);
        
        res = stmt.bind_int64(1, photoID.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.ROW) {
            if (res != Sqlite.DONE) {
                fatal("%s get_filesize".printf(table_name), res);
            }
            
            return -1;
        }
        
        return stmt.column_int(0);
    }
}

public struct EventID {
    public static const int64 INVALID = -1;

    public int64 id;
    
    public EventID(int64 id = INVALID) {
        this.id = id;
    }
    
    public bool is_invalid() {
        return (id == INVALID);
    }
    
    public bool is_valid() {
        return (id != INVALID);
    }
}

public class EventTable : DatabaseTable {
    public EventTable() {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("CREATE TABLE IF NOT EXISTS EventTable ("
            + "id INTEGER PRIMARY KEY, "
            + "name TEXT, "
            + "primary_photo_id INTEGER, "
            + "start_time INTEGER, "
            + "end_time INTEGER, "
            + "time_created INTEGER"
            + ")", -1, out stmt);
        assert(res == Sqlite.OK);

        res = stmt.step();
        if (res != Sqlite.DONE) {
            fatal("create photo table", res);
        }
    }
    
    public EventID create(PhotoID primary_photo_id, time_t start_time) {
        assert(primary_photo_id.is_valid());
        assert(start_time != 0);
        
        TimeVal time_created = TimeVal();
        time_created.get_current_time();
        
        Sqlite.Statement stmt;
        int res = db.prepare_v2(
            "INSERT INTO EventTable (primary_photo_id, time_created, start_time) VALUES (?, ?, ?)",
            -1, out stmt);
        assert(res == Sqlite.OK);
        
        res = stmt.bind_int64(1, primary_photo_id.id);
        assert(res == Sqlite.OK);
        res = stmt.bind_int64(2, time_created.tv_sec);
        assert(res == Sqlite.OK);
        res = stmt.bind_int64(3, start_time);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.DONE) {
            fatal("create_event", res);
            
            return EventID();
        }

        return EventID(db.last_insert_rowid());;
    }
    
    public bool remove(EventID event_id) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("DELETE FROM EventTable WHERE id=?", -1, out stmt);
        assert(res == Sqlite.OK);

        res = stmt.bind_int64(1, event_id.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.DONE) {
            warning("event remove", res);
            
            return false;
        }
        
        return true;
    }
    
    public bool set_end_time(EventID event_id, time_t end_time) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("UPDATE EventTable SET end_time = ? WHERE id = ?", -1, out stmt);
        assert(res == Sqlite.OK);
        
        res = stmt.bind_int64(1, end_time);
        assert(res == Sqlite.OK);
        res = stmt.bind_int64(2, event_id.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.DONE) {
            fatal("set_end_time", res);
            
            return false;
        }
        
        return true;
    }
    
    public EventID[] get_events() {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("SELECT id FROM EventTable", -1, out stmt);
        assert(res == Sqlite.OK);

        EventID[] eventIds = new EventID[0];
        for (;;) {
            res = stmt.step();
            if (res == Sqlite.DONE) {
                break;
            } else if (res != Sqlite.ROW) {
                fatal("get_events_ids", res);

                break;
            }
            
            eventIds += EventID(stmt.column_int64(0));
        }
        
        return eventIds;
    }
    
    public bool rename(EventID event_id, string name) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("UPDATE EventTable SET name = ? WHERE id = ?", -1, out stmt);
        assert(res == Sqlite.OK);
        
        res = stmt.bind_text(1, name);
        assert(res == Sqlite.OK);
        res = stmt.bind_int64(2, event_id.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.DONE) {
            fatal("event rename", res);
            
            return false;
        }
        
        return true;
    }
    
    public string? get_name(EventID eventID) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("SELECT name, start_time FROM EventTable WHERE id=?", -1, out stmt);
        assert(res == Sqlite.OK);
        
        res = stmt.bind_int64(1, eventID.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.ROW) {
            if (res != Sqlite.DONE) {
                fatal("event get_name", res);
            }
            
            return null;
        }
        
        // if no name, pretty up the start time
        string name = stmt.column_text(0);
        if ((name == null) || (name.length == 0)) {
            int64 timet = stmt.column_int64(1);
            assert(timet != 0);
            
            Time start_time = Time.local((time_t) timet);
            name = start_time.format("%a %b %e, %Y");
        }
        
        return name;
    }
    
    public PhotoID get_primary_photo(EventID eventID) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("SELECT primary_photo_id FROM EventTable WHERE id=?", -1, out stmt);
        assert(res == Sqlite.OK);
        
        res = stmt.bind_int64(1, eventID.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.ROW) {
            if (res != Sqlite.DONE) {
                fatal("event get_name", res);
            }
            
            return PhotoID();
        }
        
        return PhotoID(stmt.column_int(0));
    }
    
    public bool set_primary_photo(EventID event_id, PhotoID photo_id) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2("UPDATE EventTable SET primary_photo_id = ? WHERE id = ?", -1, out stmt);
        assert(res == Sqlite.OK);
        
        res = stmt.bind_int64(1, photo_id.id);
        assert(res == Sqlite.OK);
        res = stmt.bind_int64(2, event_id.id);
        assert(res == Sqlite.OK);
        
        res = stmt.step();
        if (res != Sqlite.DONE) {
            fatal("set_primary_photo", res);
            
            return false;
        }
        
        return true;
    }
}

public struct PhotoRow {
    public PhotoID photo_id;
    public File file;
    public Dimensions dim;
    public int64 filesize;
    public long timestamp;
    public long exposure_time;
    public Orientation orientation;
    public Orientation original_orientation;
    public ImportID import_id;
    public EventID event_id;
}

