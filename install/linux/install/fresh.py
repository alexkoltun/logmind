#!/usr/bin/python

import os
import sys
import shutil
from subprocess import call, Popen, PIPE

from common import Common, ShellColors
from install_base import InstallBase


class FreshInstall(InstallBase):

    def copy_files(self):
        try:
            if os.path.exists(Common.Paths.LOGMIND_PATH):
                shutil.rmtree(Common.Paths.LOGMIND_PATH)
            
            if os.path.exists("/service"):
                shutil.rmtree("/service")
            
            if os.path.exists("/command"):
                shutil.rmtree("/command")


            os.makedirs(Common.Paths.LOGMIND_PATH)
            dirs = os.listdir("logmind/")
            for d in dirs:
                sys.stdout.write(".")
                sys.stdout.flush()
                src = "/".join(("logmind", d))
                dst = "/".join((Common.Paths.LOGMIND_PATH, d))
                if os.path.isdir(src):
                    shutil.copytree(src, dst)
                else:
                    shutil.copy(src, dst)
                sys.stdout.write(".")
                sys.stdout.flush()
                
            sys.stdout.write("..........")
            sys.stdout.flush()
            shutil.copytree("daemontools-0.76", "/".join((Common.Paths.LOGMIND_PATH, "daemontools-0.76")))
            sys.stdout.write(".")
            sys.stdout.flush()

            print

            return True

        except Exception, e:
            print "ERROR: ", e
            return False

        

    def prep_links(self, curdir):

        try:
            os.chdir("/service")

            os.symlink("/".join((Common.Paths.LOGMIND_PATH, "elasticsearch", "service")), "logmind-elasticsearch")
            os.symlink("/".join((Common.Paths.LOGMIND_PATH, "redis", "service")), "logmind-redis")
            os.symlink("/".join((Common.Paths.LOGMIND_PATH, "openmind", "service")), "logmind-openmind")
            os.symlink("/".join((Common.Paths.LOGMIND_PATH, "sixthsense", "indexer", "service")), "logmind-indexer")
            os.symlink("/".join((Common.Paths.LOGMIND_PATH, "sixthsense", "shipper", "service")), "logmind-shipper")

            os.chdir(curdir)

            return True

        except Exception, e:
            print "ERROR: ", e
            return False



    def update_file(self, file_path, old_string, new_string):
        f = open(file_path, "rb")
        f_str = f.read()
        f.close()

        f_str = f_str.replace(old_string, new_string)
        f = open(file_path, "wb")
        f.write(f_str)
        f.close()


    def post_install(self):

        try:

            arg_index = -1
            if "--cluster-name" in sys.argv:
                arg_index = sys.argv.index("--cluster-name")
            if arg_index > -1 and len(sys.argv) > arg_index + 1:
                cluster_name = sys.argv[arg_index + 1]
            else:
                cluster_name = Common.user_input("Please enter unique Logmind installation name (ElasticSearch Cluster name): ")
                
            print "Using cluster name: ", cluster_name
            
            es_conf_file = "/".join((Common.Paths.LOGMIND_PATH, "elasticsearch", "config", "elasticsearch.yml"))
            self.update_file(es_conf_file, "[LOGMIND_ES_CLUSTER_NAME]", cluster_name)
            
            indexer_conf_file = "/".join((Common.Paths.LOGMIND_PATH, "sixthsense", "config", "indexer.conf", "logmind-indexer.conf"))
            self.update_file(indexer_conf_file, "[LOGMIND_ES_CLUSTER_NAME]", cluster_name)
            
            

            return True

        except Exception, e:
            print "ERROR: ", e
            return False
        


    def do_install(self):
        print "Installing Logmind to", Common.Paths.LOGMIND_PATH

        print "Copying files..."
        if self.copy_files():

            print "Setting permissions..."
            if self.set_permissions():

                if self.set_attrs():

                    print "Installing services..."
                    curdir = os.path.abspath(os.curdir)

                    if self.inst_daemon(curdir):

                        if self.prep_links(curdir):

                            print "Running post-installation operations..."
                            if self.post_install():

                                print "Starting services..."
                                if self.start_services():
                                    print ShellColors.OKGREEN + "Logmind installed successfully!" + ShellColors.ENDC

