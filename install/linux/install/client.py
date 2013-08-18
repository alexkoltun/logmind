#!/usr/bin/python

import os
import sys
import shutil
from subprocess import call, Popen, PIPE

from common import Common, ShellColors
from install_base import InstallBase


class ClientInstall(InstallBase):

    def copy_files(self):
        try:
            if os.path.exists(Common.Paths.LOGMIND_PATH):
                shutil.rmtree(Common.Paths.LOGMIND_PATH)
            
            if os.path.exists("/service"):
                shutil.rmtree("/service")
            
            if os.path.exists("/command"):
                shutil.rmtree("/command")


            os.makedirs(Common.Paths.LOGMIND_PATH)
            client_dir_name = "sixthsense"

            sys.stdout.write("..")
            sys.stdout.flush()
            
            src = "/".join((os.path.dirname(sys.argv[0]), "logmind", client_dir_name))
            dst = "/".join((Common.Paths.LOGMIND_PATH, client_dir_name))
            shutil.copytree(src, dst)
            
            sys.stdout.write("........")
            sys.stdout.flush()
                
            sys.stdout.write("..")
            sys.stdout.flush()
            shutil.copytree("/".join((os.path.dirname(sys.argv[0]), "daemontools-0.76")), "/".join((Common.Paths.LOGMIND_PATH, "daemontools-0.76")))
            sys.stdout.write("........")
            sys.stdout.flush()

            print

            return True

        except Exception, e:
            print "ERROR: ", e
            return False

        

    def prep_links(self, curdir):

        try:
            os.chdir("/service")

            os.symlink("/".join((Common.Paths.LOGMIND_PATH, "sixthsense", "shipper", "service")), "logmind-shipper")

            os.chdir(curdir)

            return True

        except Exception, e:
            print "ERROR: ", e
            return False


    def do_install(self):
        print "Installing Logmind Client to", Common.Paths.LOGMIND_PATH

        print "Copying files..."
        if self.copy_files():

            print "Setting permissions..."
            if self.set_permissions_client():

                if self.set_attrs():

                    print "Installing services..."
                    curdir = os.path.abspath(os.curdir)

                    if self.inst_daemon(curdir):

                        if self.prep_links(curdir):

                                print "Starting services..."
                                if self.start_services():
                                    print ShellColors.OKGREEN + "Logmind Client installed successfully!" + ShellColors.ENDC

