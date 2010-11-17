/* Copyright 2009-2010 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution. 
 */

// Returns true if the file is claimed, false if it exists, and throws an Error otherwise.  The file
// will be created when the function exits and should be overwritten.  Note that the file is not
// held open; claiming a file is merely based on its existance.
//
// This function is thread-safe.
public bool claim_file(File file) throws Error {
    try {
        file.create(FileCreateFlags.NONE, null);
        
        // created; success
        return true;
    } catch (Error err) {
        // check for file-exists error
        if (!(err is IOError.EXISTS)) {
            warning("claim_file %s: %s", file.get_path(), err.message);
            
            throw err;
        }
        
        return false;
    }
}

// This function "claims" a file on the filesystem in the directory specified with a basename the
// same or similar as what has been requested (adds numerals to the end of the name until a unique
// one has been found).  The file may exist when this function returns, and it should be
// overwritten.  It does *not* attempt to create the parent directory, however.
//
// This function is thread-safe.
public File? generate_unique_file(File dir, string basename, out bool collision) throws Error {
    // create the file to atomically "claim" it
    File file = dir.get_child(basename);
    if (claim_file(file)) {
        collision = false;
        
        return file;
    }
    
    // file exists, note collision and keep searching
    collision = true;
    
    string name, ext;
    disassemble_filename(basename, out name, out ext);
    
    // generate a unique filename
    for (int ctr = 1; ctr < int.MAX; ctr++) {
        string new_name = (ext != null) ? "%s_%d.%s".printf(name, ctr, ext) : "%s_%d".printf(name, ctr);
        
        file = dir.get_child(new_name);
        if (claim_file(file))
            return file;
    }
    
    warning("generate_unique_filename %s for %s: unable to claim file", dir.get_path(), basename);
    
    return null;
}

public void disassemble_filename(string basename, out string name, out string ext) {
    long offset = find_last_offset(basename, '.');
    if (offset <= 0) {
        name = basename;
        ext = null;
    } else {
        name = basename.substring(0, offset);
        ext = basename.substring(offset + 1, -1);
    }
}

// This function is thread-safe.
public uint64 query_total_file_size(File file_or_dir, Cancellable? cancellable = null) throws Error {
    FileType type = file_or_dir.query_file_type(FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null);
    if (type == FileType.REGULAR) {
        FileInfo info = null;
        try {
            info = file_or_dir.query_info(FILE_ATTRIBUTE_STANDARD_SIZE, 
                FileQueryInfoFlags.NOFOLLOW_SYMLINKS, cancellable);
        } catch (Error err) {
            if (err is IOError.CANCELLED)
                throw err;
            
            debug("Unable to query filesize for %s: %s", file_or_dir.get_path(), err.message);

            return 0;
        }
        
        return info.get_size();
    } else if (type != FileType.DIRECTORY) {
        return 0;
    }
        
    FileEnumerator enumerator;
    try {
        enumerator = file_or_dir.enumerate_children(FILE_ATTRIBUTE_STANDARD_NAME,
            FileQueryInfoFlags.NOFOLLOW_SYMLINKS, cancellable);
        if (enumerator == null)
            return 0;
    } catch (Error err) {
        // Don't treat a permissions failure as a hard failure, just skip the directory
        if (err is FileError.PERM || err is IOError.PERMISSION_DENIED)
            return 0;
        
        throw err;
    }
    
    uint64 total_bytes = 0;
        
    FileInfo info = null;
    while ((info = enumerator.next_file(cancellable)) != null)
        total_bytes += query_total_file_size(file_or_dir.get_child(info.get_name()), cancellable);
    
    return total_bytes;
}

public time_t query_file_modified(File file) throws Error {
    FileInfo info = file.query_info(FILE_ATTRIBUTE_TIME_MODIFIED, FileQueryInfoFlags.NOFOLLOW_SYMLINKS, 
        null);

    TimeVal timestamp = TimeVal();
    info.get_modification_time(out timestamp);
    
    return timestamp.tv_sec;
}

public bool query_is_directory(File file) {
    return file.query_file_type(FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null) == FileType.DIRECTORY;
}

public bool query_is_directory_empty(File dir) throws Error {
    if (dir.query_file_type(FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null) != FileType.DIRECTORY)
        return false;
    
    FileEnumerator enumerator = dir.enumerate_children("standard::name",
        FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null);
    if (enumerator == null)
        return false;
    
    return enumerator.next_file(null) == null;
}

public string get_display_pathname(File file) {
    // attempt to replace home path with tilde in a user-pleasable way
    string path = file.get_parse_name();
    string home = Environment.get_home_dir();

    if (path == home)
        return "~";
    
    if (path.has_prefix(home))
        return "~%s".printf(path.substring(home.length));

    return path;
}

public string strip_pretty_path(string path) {
    if (!path.has_prefix("~"))
        return path;
    
    return Environment.get_home_dir() + path.substring(1);
}

public string? get_file_info_id(FileInfo info) {
    return info.get_attribute_string(FILE_ATTRIBUTE_ID_FILE);
}

public string get_root_directory() {
#if WINDOWS
    return "C:\\";
#else
    return "/";
#endif
}
