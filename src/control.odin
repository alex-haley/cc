package control

import f "core:fmt"
import s "core:strings"
import   "core:os"

import "core:path/filepath"

CC_DIR   :: ".cc";
MANIFEST :: "manifest.log";
VERSION  :: "version";

fill_hash_map :: proc(version_path: string, hash_map: ^map[string]i64)
{
    cur_folder, opening_error := os.open(version_path);
    defer os.close(cur_folder);
    if opening_error != os.ERROR_NONE {
        f.printf("could not open directory for reading, sad\n");
        os.exit(1);
    }
    
    fis, reading_error := os.read_dir(cur_folder, -1);
    defer os.file_info_slice_delete(fis);
    if reading_error != os.ERROR_NONE {
        f.printf("could not read directory, sad\n");
        os.exit(1);
    }
    
    for item in fis {
        if item.is_dir {
            fill_hash_map(item.fullpath, hash_map);
        } else {
            latest_write := item.modification_time._nsec;
            hash_map[item.name] = latest_write;
        }
    }
}

write_files :: proc(cur_path, version_path: string, hash_map: map[string]i64)
{
    cur_folder, opening_error := os.open(cur_path);
    defer os.close(cur_folder);
    if opening_error != os.ERROR_NONE {
        f.printf("could not open directory for reading, sad\n");
        os.exit(1);
    }
    
    fis, reading_error := os.read_dir(cur_folder, -1);
    defer os.file_info_slice_delete(fis);
    if reading_error != os.ERROR_NONE {
        f.printf("could not read directory, sad\n");
        os.exit(1);
    }
    
    for item in fis {
        if item.is_dir {
            if item.name != CC_DIR {
                version_inner_dir_path := filepath.join({version_path, item.name});
                os.make_directory(version_inner_dir_path, 0);
                write_files(item.fullpath, version_inner_dir_path, hash_map);
            }
        } else {
            latest_write := item.modification_time._nsec;
            if latest_write != hash_map[item.name] {
                file_contents, succ := os.read_entire_file(item.fullpath);
                if !succ {
                    f.printf("error while reading: %s\n", item.name);
                    f.printf("skipping...\n");
                    continue;
                }
                where_to_copy := filepath.join({version_path, item.name});
                os.write_entire_file(where_to_copy, file_contents);
            }
        }
    }
}

update_cur_version :: proc(cur_path, version_path: string)
{
    hash_map := make(map[string]i64);
    defer delete(hash_map);
    
    fill_hash_map(version_path, &hash_map);
    write_files(cur_path, version_path, hash_map);
}

create_new_version :: proc(cur_path, version_path: string)
{
    cur_folder, opening_error := os.open(cur_path);
    defer os.close(cur_folder);
    if opening_error != os.ERROR_NONE {
        f.printf("could not open directory for reading, sad\n");
        os.exit(1);
    }
    
    fis, reading_error := os.read_dir(cur_folder, -1);
    defer os.file_info_slice_delete(fis);
    if reading_error != os.ERROR_NONE {
        f.printf("could not read directory, sad\n");
        os.exit(1);
    }
    
    for item in fis {
        if item.is_dir {
            if item.name != CC_DIR {
                version_inner_dir_path := filepath.join({version_path, item.name});
                os.make_directory(version_inner_dir_path, 0);
                create_new_version(item.fullpath, version_inner_dir_path);
            }
        } else {
            file_contents, succ := os.read_entire_file(item.fullpath);
            if !succ {
                f.printf("error while reading: %s\n", item.name);
                f.printf("skipping...\n");
            }
            where_to_copy := filepath.join({version_path, item.name});
            os.write_entire_file(where_to_copy, file_contents);
        }
    }
}

show_help :: proc()
{
    f.printf("\nv - create new version\n");
    f.printf("u - update current version (if exists)\n");
}

main :: proc()
{
    cur_path := os.get_current_directory();
    cc_dir   := CC_DIR;
    manifest := MANIFEST;
    version  := VERSION;
    
    if len(os.args) < 2 {
        f.printf("no arguments!\n");
        show_help();
        os.exit(1);
    }
    
    cc_path := filepath.join({cur_path, cc_dir});
    manifest_path := filepath.join({cc_path, manifest});
    
    if !os.is_dir(cc_path) {
        f.printf("there is no CC directory!\n");
        f.printf("creating directory in path:\n");
        f.printf("%s\n", cc_path);
        os.make_directory(cc_path, 0);
    }
    
    manifest_version, succ := os.read_entire_file(manifest_path);
    if !succ {
        manifest_version = {'1'};
    } else {
        if os.args[1] == "v" {
            manifest_version[0] += 1;
        }
    }
    os.write_entire_file(manifest_path, manifest_version);
    
    version_with_number := s.concatenate({version, string(manifest_version)});
    version_path := filepath.join({cc_path, version_with_number});
    if !os.is_dir(version_path) {
        os.make_directory(version_path, 0);
    }
    
    if os.args[1] == "v" || !succ {
        create_new_version(cur_path, version_path);
    } else if os.args[1] == "u" {
        update_cur_version(cur_path, version_path);
    } else {
        show_help();
    }
}
