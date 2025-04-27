package control

import f "core:fmt"
import s "core:strings"
import "core:os"

import "core:path/filepath"

// TODO(alex-haley): make proper handle checking,
// and try to make 'status' function to check wether
// file was edited or not, so we will save edited files
// in new version, and if there is no updates, we wouldn't
// create a new version.

// NOTE(alex-haley): what i was thinking about today
// i guess we will have two different ways to 'commit'
// to the repository - update current version, or
// create new version.
//
// when we just doing update of the current version,
// we add new lines to the files, and delete deleted lines,
// and write log inside this version about what was changed
//
// when we do new version, we just straight up copying
// the files from the folder, and that's it.

copy_files_to_cc :: proc(cur_path, version_path: string)
{
    cur_folder, opening_error := os.open(cur_path);
    defer os.close(cur_folder);
    if opening_error != os.ERROR_NONE {
	f.printf("could not open directory for reading, sad");
	os.exit(1);
    }

    fis, reading_error := os.read_dir(cur_folder, -1)
    defer os.file_info_slice_delete(fis);
    if reading_error != os.ERROR_NONE {
	f.printf("could not read directory, sad");
	os.exit(1);
    }

    for item in fis {
	_, itemname := filepath.split(item.fullpath);

	if item.is_dir {
	    if itemname != ".cc" {
		version_inner_dir_path := filepath.join({version_path, itemname});
		os.make_directory(version_inner_dir_path, 0);
		copy_files_to_cc(item.fullpath, version_inner_dir_path);
	    }
	} else {
	    file_contents, succ := os.read_entire_file(item.fullpath);
	    if !succ {
		f.printf("error while reading: %s\n", itemname);
		f.printf("this file will not be included in new version!\n");
	    }
	    where_to_copy := filepath.join({version_path, itemname});
	    os.write_entire_file(where_to_copy, file_contents);
	}
    }
}

main :: proc()
{
    cur_path := os.get_current_directory();
    cc_dir   := ".cc";
    manifest := "manifest.log";
    version  := "version";

    cc_path := filepath.join({cur_path, cc_dir});
    manifest_path := filepath.join({cc_path, manifest});

    if !os.is_dir(cc_path) {
	f.printf("there is no CC directory!\n");
	f.printf("creating directory in path:\n");
	f.printf("%s\n", cc_path);
	os.make_directory(cc_path, 0);
    }

    // TODO(alex-haley): combine this two cases in one! check only for manifest file, take everything
    // out of the if statements...

    manifest_version, succ := os.read_entire_file(manifest_path);
    if !succ {
	manifest_version = {'1'};
    } else {
	manifest_version[0] += 1;
    }
    os.write_entire_file(manifest_path, manifest_version);

    version_with_number := s.concatenate({version, string(manifest_version)});
    version_path := filepath.join({cc_path, version_with_number});
    os.make_directory(version_path, 0);

    copy_files_to_cc(cur_path, version_path);
}
