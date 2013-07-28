#!/usr/bin/python

import os
import sys

execfile("/".join((os.path.dirname(os.path.realpath(sys.argv[0])), "install", "install_base.py")))

#######################
#### I N S T A L L ####
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

                        print "Running post-installation operations..."
                        if post_install():

                            print "Starting services..."
                            if start_services():
                                print ShellColors.OKGREEN + "Logmind installed successfully!" + ShellColors.ENDC



__main__()
