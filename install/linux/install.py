#!/usr/bin/python

import sys
import os
import time

from install.common import Common, ShellColors
from install.version import Version
from install.fresh import FreshInstall
from install.upgrade import UpgradeInstall



#######################
#### M E T H O D S ####
#######################

def check_prereq():
    if "-force" in sys.argv:
        print "Skipping prerequisites check. Forcing installation..."
        return True
    else:
        return check_java() and check_ports()


def check_java():
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


def check_ports():
    import socket
    try:
        print "Making sure required ports are not in use... (", Common.PORTS_TO_TEST, ")"

        for port in Common.PORTS_TO_TEST:
            try:
                # Issue the socket connect on the host:port
        
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(60)
                sock.bind(("", port))
                
            except Exception, e:
                    print ShellColors.FAIL + "Port " + str(port) + " is not available - Please make sure it is not in use by any other application (" + str(e) + ")." + ShellColors.ENDC
                    return False
                
            else:
                    print ShellColors.OKGREEN + "Port " + str(port) + " is available" + ShellColors.ENDC

            if sock is not None:        
                sock.close()
            
        return True

    except Exception, e:
        print "ERROR: ", e
        return False




def show_help():
    print ShellColors.HEADER + "Logmind Installation Utility" + ShellColors.ENDC
    print ShellColors.OKBLUE + "Usage: install.py [options]" + ShellColors.ENDC
    print "Options:"
    print "     -mode (fresh/upgrade):  Only affects machines with previous installations."
    print "                             Fresh mode will overwrite current installation, discarding all settings and data."
    print "                             Upgrade mode will upgrade current installation, keeping all settings and data."
    print "     -upgrade-only (elasticsearch, openmind, redis, sixthsense):     One or more option. Comma separated."
    print "                                                                     Upgrade only selected components."
    print "     -backup:                Backup upgraded components."
    print "     -time:                  Calculate installation time."
    print "     -h / -help / --help:    Show this help."
            


#######################
####### M A I N #######
#######################

def __main__() :

    if any(h in sys.argv for h in ["-h", "-help", "--help"]):
        show_help()
        return True

    start_time = time.time()

    print "Checking prerequisites..."
    if check_prereq():

        mode = sys.argv[sys.argv.index("-mode") + 1] if "-mode" in sys.argv else None

        if os.path.exists(Common.Paths.LOGMIND_PATH):
            ver_dict = Common.get_versions_dict()
            current_version = ver_dict["GENERAL"] if ver_dict["GENERAL"] != 0 else "Unknown"
            while mode is None:
                print "A previous version of Logmind (", current_version, ") is already installed. Please select an option:"
                print "1. Overwrite current installation"
                print "2. Upgrade to version", Version.VERSION["GENERAL"]
                c = Common.user_input("Please Select (1 or 2): ").strip()
                if c == "1":
                    mode = "fresh"
                elif c == "2":
                    mode = "upgrade"
                    
        if mode == None or mode == "fresh":
            print "Running a fresh installation..."
            installer = FreshInstall()
            
        elif mode == "upgrade":
            print "Upgrading to version " + Version.VERSION["GENERAL"] + "..."
            installer = UpgradeInstall()

        else:
            print "Unknown mode '" + mode + "'. Installation aborted."
            return False

        installer.do_install()

    end_time = time.time()

    if "-time" in sys.argv:
        print "Process completed in", end_time - start_time, "seconds"


__main__()
