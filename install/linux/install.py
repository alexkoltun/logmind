#!/usr/bin/python

import os
import sys
import shutil
from subprocess import call, Popen


LOGMIND_PATH = "/usr/local/logmind"


#######################
#### M E T H O D S ####
#######################

def prompt(msg):
    res = ""
    while not res.strip().lower() in ["y", "n"]:
        res = raw_input(msg)

    return res


def uninstall_previous():
    if os.path.exists(LOGMIND_PATH):
        shutil.rmtree(LOGMIND_PATH)

    if os.path.exists("/service"):
        shutil.rmtree("/service")

    if os.path.exists("/command"):
        shutil.rmtree("/command")
                      


def copy_files():
    try:
        if os.path.exists(LOGMIND_PATH):
            c = prompt("A previous Logmind installation already exists at '" + LOGMIND_PATH + "'. Overwrite? (y/n): ")
            if c == "y":
                uninstall_previous()
            else:
                print "Installation aborted."
                return False

        os.makedirs(LOGMIND_PATH)
        dirs = os.listdir("logmind/")
        for d in dirs:
            sys.stdout.write(".")
            sys.stdout.flush()
            src = "/".join(("logmind", d))
            dst = "/".join((LOGMIND_PATH, d))
            shutil.copytree(src, dst)
            sys.stdout.write(".")
            sys.stdout.flush()
            
        sys.stdout.write("..........")
        sys.stdout.flush()
        shutil.copytree("daemontools-0.76", "/".join((LOGMIND_PATH, "daemontools-0.76")))
        sys.stdout.write(".")
        sys.stdout.flush()

        print

        return True

    except Exception, e:
        print "ERROR: ", e
        return False



def set_permissions():

    try:
        os.chmod(LOGMIND_PATH + "/elasticsearch/service/run", 0755)
        os.chmod(LOGMIND_PATH + "/elasticsearch/service/log/run", 0755)
        os.chmod(LOGMIND_PATH + "/elasticsearch/bin/elasticsearch", 0755)
        os.chmod(LOGMIND_PATH + "/redis/service/run", 0755)
        os.chmod(LOGMIND_PATH + "/redis/service/log/run", 0755)
        os.chmod(LOGMIND_PATH + "/redis/redis-server", 0755)
        os.chmod(LOGMIND_PATH + "/openmind/service/run", 0755)
        os.chmod(LOGMIND_PATH + "/openmind/service/log/run", 0755)
        os.chmod(LOGMIND_PATH + "/sixthsense/sixthsense.sh", 0755)
        os.chmod(LOGMIND_PATH + "/sixthsense/indexer/service/run", 0755)
        os.chmod(LOGMIND_PATH + "/sixthsense/indexer/service/log/run", 0755)
        os.chmod(LOGMIND_PATH + "/sixthsense/shipper/service/run", 0755)
        os.chmod(LOGMIND_PATH + "/sixthsense/shipper/service/log/run", 0755)
        os.chmod(LOGMIND_PATH + "/daemontools-0.76/package/upgrade", 0755)
        os.chmod(LOGMIND_PATH + "/daemontools-0.76/package/run", 0755)
        os.chmod(LOGMIND_PATH + "/daemontools-0.76/package/run-generic", 0755)
        os.chmod(LOGMIND_PATH + "/daemontools-0.76/package/run-ubuntu", 0755)
        os.chmod(LOGMIND_PATH + "/daemontools-0.76/package/run.inittab", 0755)
        
        commands_path = LOGMIND_PATH + "/daemontools-0.76/command"
        commands = os.listdir(commands_path)
        for c in commands:
            os.chmod("/".join((commands_path, c)), 0755)

        return True

    except Exception, e:
        print "ERROR: ", e
        return False
    


def set_attrs():
    return True

def inst_daemon(curdir):

    try:
        os.chdir("/".join((LOGMIND_PATH, "daemontools-0.76")))

        ret_upgrade = call(["package/upgrade"])
        ret_run = call(["package/run"])
        success = ret_upgrade == ret_run== 0

        os.chdir(curdir)

        if not success:
            print "Error while installing services."
        
        return success

    except Exception, e:
        print "ERROR: ", e
        return False

    

def prep_links(curdir):

    try:
        os.chdir("/service")

        os.symlink("/".join((LOGMIND_PATH, "elasticsearch", "service")), "logmind-elasticsearch")
        os.symlink("/".join((LOGMIND_PATH, "redis", "service")), "logmind-redis")
        os.symlink("/".join((LOGMIND_PATH, "openmind", "service")), "logmind-openmind")
        os.symlink("/".join((LOGMIND_PATH, "sixthsense", "indexer", "service")), "logmind-indexer")
        os.symlink("/".join((LOGMIND_PATH, "sixthsense", "shipper", "service")), "logmind-shipper")

        os.chdir(curdir)

        return True

    except Exception, e:
        print "ERROR: ", e
        return False
    return True


def finalize_inst():

    try:

        if "Ubuntu" in os.uname()[3]:
            print "Starting services on Ubuntu Linux OS..."

            pid = Popen(["svscanboot"]).pid
            print "svscanboot started with PID", pid

        
        return True

    except Exception, e:
        print "ERROR: ", e
        return False




#######################
####### M A I N #######
#######################

def __main__() :

    print "Installing Logmind to", LOGMIND_PATH

    print "Copying files..."
    if copy_files():

        print "Setting permissions..."
        if set_permissions():

            if set_attrs():

                print "Installing services..."
                curdir = os.path.abspath(os.curdir)

                if inst_daemon(curdir):

                    if prep_links(curdir):

                        if finalize_inst():
                            print "Logmind installed successfully!"



__main__()
