#!/usr/bin/python

import os
import sys
import shutil



def __main__():

    if len(sys.argv) < 3:
        print sys.argv, " - command-line arguments missing"
        print "Usage: flatten-directories.py LOGMIND_PATH BUILD_PLATFORM"
        return

    path = sys.argv[1]
    build_platform = sys.argv[2]

    try:
        components = [d for d in os.listdir(path) if os.path.isdir(path + "/" + d)]
        for c in components:
            component_path = "/".join((path, c))
            platform_folder = [d for d in os.listdir(component_path) if os.path.isdir("/".join((component_path, d)))]
            if "platform" in platform_folder:
                platform_path = "/".join((component_path, "platform"))
                build_platform_folder = [d for d in os.listdir(platform_path) if os.path.isdir("/".join((platform_path, d)))]
                if build_platform in build_platform_folder:
                    # Move to top
                    build_platform_path = "/".join((platform_path, build_platform))
                    for item in os.listdir(build_platform_path):
                        item_path = "/".join((build_platform_path, item))
                        print "Moving", item_path, "to", component_path
                        shutil.move(item_path, "/".join((component_path, item)))
                    # Remove platform dir
                    print "Removing", platform_path
                    shutil.rmtree(platform_path)

        print "Done!"
                
        
    except StopIteration:
        pass



__main__()
