#!/usr/bin/python

import sys
import os
import time

execfile("/".join((os.path.dirname(os.path.realpath(sys.argv[0])), "install", "common.py")))
execfile("/".join((os.path.dirname(os.path.realpath(sys.argv[0])), "install", "version.py")))



#######################
#### M E T H O D S ####
#######################

def check_prereq():
    try:
        print "Checking for Java...",
        java_ok = os.system("java -version") == 0
        if java_ok:
            print "[ " + ShellColors.OKGREEN + "OK" + ShellColors.ENDC + " ]"
            
        else:
            print "[ " + ShellColors.FAIL + "FAIL" + ShellColors.ENDC + " ]"
            print ShellColors.FAIL + "Please make sure Java is installed and JAVA_HOME is set, and try again" + ShellColors.ENDC
            return False

        return True

    except Exception, e:
        print "ERROR: ", e
        return False
        
            


#######################
####### M A I N #######
#######################

def __main__() :

    start_time = time.time()

    print "Checking prerequisites..."
    if check_prereq():

        mode = sys.argv[sys.argv.index("-mode") + 1] if "-mode" in sys.argv else None

        if os.path.exists(LOGMIND_PATH):
            ver_dict = get_versions_dict()
            current_version = ver_dict["GENERAL"] if ver_dict["GENERAL"] != 0 else "Unknown"
            while mode is None:
                print "A previous version of Logmind (", current_version, ") is already installed. Please select an option:"
                print "1. Overwrite current installation"
                print "2. Upgrade to version", version["GENERAL"]
                c = user_input("Please Select (1 or 2): ").strip()
                if c == "1":
                    mode = "fresh"
                elif c == "2":
                    mode = "upgrade"
                    
        if mode == None or mode == "fresh":
            print "Running a fresh installation..."
            execfile("/".join((os.path.dirname(os.path.realpath(sys.argv[0])), "install", "install.py")))
            
        elif mode == "upgrade":
            print "Upgrading to version " + version["GENERAL"] + "..."
            execfile("/".join((os.path.dirname(os.path.realpath(sys.argv[0])), "install", "upgrade.py")))

        else:
            print "Unknown mode '" + mode + "'. Installation aborted."
            return False

    end_time = time.time()

    if "-count-time" in sys.argv:
    print "Process completed in", end_time - start_time, "seconds"


__main__()
