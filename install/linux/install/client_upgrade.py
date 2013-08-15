#!/usr/bin/python

import os
import sys
import shutil
from subprocess import call, Popen, PIPE
import time

from common import Common, ShellColors
from version import Version
from install_base import InstallBase


class ClientUpgradeInstall(InstallBase):
    
    def backup_config(self):
        try:
            config_dir = "/".join((Common.Paths.LOGMIND_PATH, "backup", "config"))
            if not os.path.exists(config_dir):
                os.makedirs(config_dir)
            else:
                shutil.rmtree(config_dir)
                os.makedirs(config_dir)

            shutil.copy(Common.Paths.SHIPPER_CONF_FILE, config_dir)
            shutil.copy(Common.Paths.SHIPPER_EVENTLOG_CONF_FILE, config_dir)
            shutil.copy(Common.Paths.SHIPPER_SYSLOG_CONF_FILE, config_dir)

            return True

        except Exception, e:
            print "ERROR: ", e
            return False


    def restore_config(self):

        try:
            config_dir = "/".join((Common.Paths.LOGMIND_PATH, "backup", "config"))
            if not os.path.exists(config_dir):
                os.makedirs(config_dir)
            
            shutil.copy("/".join((config_dir, "logmind-shipper.conf")), Common.Paths.SHIPPER_CONF_FILE)
            shutil.copy("/".join((config_dir, "eventlog-filters.conf")), Common.Paths.SHIPPER_EVENTLOG_CONF_FILE)
            shutil.copy("/".join((config_dir, "syslog-endpoint.conf")), Common.Paths.SHIPPER_SYSLOG_CONF_FILE)

            return True

        except Exception, e:
            print "ERROR: ", e
            return False


    def get_upgrade_modules_list(self):
        return ["sixthsense"]



    def do_install(self):
        print "Installing Logmind to", Common.Paths.LOGMIND_PATH

        print "Stopping services..."
        if self.stop_services_upgrade(True):

            print "Backing-up config..."
            if self.backup_config():

                print "Copying files..."
                if self.copy_files_upgrade():

                    print "Setting permissions..."
                    if self.set_permissions_client():

                        if self.set_attrs():

                            print "Restoring config..."
                            if self.restore_config():

                                    print "Starting services..."
                                    if self.start_services_upgrade():
                                        print ShellColors.OKGREEN + "Logmind upgraded successfully to version " + Version.VERSION["GENERAL"] + "!" + ShellColors.ENDC


