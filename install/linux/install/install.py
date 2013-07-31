#!/usr/bin/python

import os
import sys

execfile("/".join((os.path.dirname(os.path.realpath(sys.argv[0])), "install", "install_base.py")))



#######################
#### M E T H O D S ####
#######################

def copy_files():
    try:
        if os.path.exists(LOGMIND_PATH):
            shutil.rmtree(LOGMIND_PATH)
        
        if os.path.exists("/service"):
            shutil.rmtree("/service")
        
        if os.path.exists("/command"):
            shutil.rmtree("/command")


        os.makedirs(LOGMIND_PATH)
        dirs = os.listdir("logmind/")
        for d in dirs:
            sys.stdout.write(".")
            sys.stdout.flush()
            src = "/".join(("logmind", d))
            dst = "/".join((LOGMIND_PATH, d))
            if os.path.isdir(src):
                shutil.copytree(src, dst)
            else:
                shutil.copy(src, dst)
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


def post_install():

    try:

        def update_file(file_path, old_string, new_string):
            f = open(file_path, "rb")
            f_str = f.read()
            f.close()

            f_str = f_str.replace(old_string, new_string)
            f = open(file_path, "wb")
            f.write(f_str)
            f.close()
            

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


def start_services():

    try:
        p = Popen(["uname", "-a"], stdout=PIPE)
        out, err = p.communicate()
        if "Ubuntu" in out or "CentOS-6" in out or ".el6." in out:
            print "Upstart: starting services..."
            ret_start = call(["/sbin/start", "daemontools"])

            success = ret_start == 0
            if not success:
                print "Error starting upstart services."

            return success
        

        return True

    except Exception, e:
        print "ERROR: ", e
        return False




#######################
#### I N S T A L L ####
#######################

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

                        print "Starting services..."
                        if start_services():
                            print ShellColors.OKGREEN + "Logmind installed successfully!" + ShellColors.ENDC

