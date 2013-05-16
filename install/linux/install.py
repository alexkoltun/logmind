#!/usr/bin/python

import os
import sys
import shutil
from subprocess import call



LOGMIND_PATH = "/usr/local/logmind"


class ShellColors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'


#######################
#### M E T H O D S ####
#######################

def prompt(msg):
    res = ""
    while not res.strip().lower() in ["y", "n"]:
        res = raw_input(msg)

    return res


def user_input(msg):
    res = ""
    while not len(res) > 0:
        res = raw_input(msg)

    return res


def uninstall_previous():
    if os.path.exists(LOGMIND_PATH):
        shutil.rmtree(LOGMIND_PATH)

    if os.path.exists("/service"):
        shutil.rmtree("/service")

    if os.path.exists("/command"):
        shutil.rmtree("/command")


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


def update_file(file_path, old_string, new_string):
    f = open(file_path, "rb")
    f_str = f.read()
    f.close()

    f_str = f_str.replace(old_string, new_string)
    f = open(file_path, "wb")
    f.write(f_str)
    f.close()


def post_install():

    try:
        arg_index = -1
        if "--cluster-name" in sys.argv:
            arg_index = sys.argv.index("--cluster-name")
        if arg_index > -1 and len(sys.argv) > arg_index + 1:
            cluster_name = sys.argv[arg_index + 1]
        else:
            cluster_name = user_input("Please enter unique Logmind installation name (ElasticSearch Cluster name): ")
            
        print "Using cluster name: ", cluster_name
        
        es_conf_file = "/".join((LOGMIND_PATH, "elasticsearch", "config", "elasticsearch.yml"))
        update_file(es_conf_file, "[LOGMIND_ES_CLUSTER_NAME]", cluster_name)
        
        indexer_conf_file = "/".join((LOGMIND_PATH, "sixthsense", "config", "indexer.conf", "logmind-indexer.conf"))
        update_file(indexer_conf_file, "[LOGMIND_ES_CLUSTER_NAME]", cluster_name)
        
        

        return True

    except Exception, e:
        print "ERROR: ", e
        return False

        





#######################
####### M A I N #######
#######################

def __main__() :

    print "Checking prerequisites..."
    if check_prereq():

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
 
                            print "Running post-installation operations..."
                            if post_install():
                                print ShellColors.OKGREEN + "Logmind installed successfully!" + ShellColors.ENDC



__main__()
