#!/usr/bin/python

import os
import sys
import shutil
from subprocess import call, Popen, PIPE
import time

from common import Common, ShellColors
from version import Version
from install_base import InstallBase


class UpgradeInstall(InstallBase):

    def stop_services(self):
        try:
            success = call(["/command/svcs-d"]) == 0

            if success:
                is_down = False
                while not is_down:
                    print "Waiting for services to stop..."
                    time.sleep(5)
                    p = Popen("/command/svstats", stdout=PIPE)
                    out,err = p.communicate()
                    is_down = out.count("down") == 5
                
            else:
                print "Error while stopping services."
            
            return success

        except Exception, e:
            print "ERROR: ", e
            return False
        

    def start_services(self):
        try:
            success = call(["/command/svcs-u"]) == 0

            if not success:
                print "Error while starting services."
            
            return success

        except Exception, e:
            print "ERROR: ", e
            return False

        

    def backup_config(self):
        try:
            config_dir = "/".join((Common.Paths.LOGMIND_PATH, "backup", "config"))
            if not os.path.exists(config_dir):
                os.makedirs(config_dir)
            else:
                shutil.rmtree(config_dir)
                os.makedirs(config_dir)
            
            shutil.copy(Common.Paths.ES_CONF_FILE, config_dir)
            shutil.copy(Common.Paths.OPENMIND_CONF_FILE, config_dir)
            shutil.copy(Common.Paths.INDEXER_CONF_FILE, config_dir)
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
            
            shutil.copy("/".join((config_dir, "elasticsearch.yml")), Common.Paths.ES_CONF_FILE)
            shutil.copy("/".join((config_dir, "GlobalConfig.rb")), Common.Paths.OPENMIND_CONF_FILE)
            shutil.copy("/".join((config_dir, "logmind-indexer.conf")), Common.Paths.INDEXER_CONF_FILE)
            shutil.copy("/".join((config_dir, "logmind-shipper.conf")), Common.Paths.SHIPPER_CONF_FILE)
            shutil.copy("/".join((config_dir, "eventlog-filters.conf")), Common.Paths.SHIPPER_EVENTLOG_CONF_FILE)
            shutil.copy("/".join((config_dir, "syslog-endpoint.conf")), Common.Paths.SHIPPER_SYSLOG_CONF_FILE)

            return True

        except Exception, e:
            print "ERROR: ", e
            return False


    def copy_files(self):
        try:
            upgrade_modules = sys.argv[sys.argv.index("-upgrade-only") + 1].split(",") if "-upgrade-only" in sys.argv else ["elasticsearch","openmind","sixthsense","redis"]
            backup_all = "-backup" in sys.argv
            ver_dict = Common.get_versions_dict()

            backup_dir = "/".join((Common.Paths.LOGMIND_PATH, "backup", "components"))
            if not os.path.exists(backup_dir):
                os.makedirs(backup_dir)
            else:
                shutil.rmtree(backup_dir)
                os.makedirs(backup_dir)

            for module in upgrade_modules:
                module = module.strip()
                print "Upgrading " + module + " from version '" + str(ver_dict[module]) + "' to version '" + str(Version.VERSION[module]) + "'"

                for d in Common.Paths.COMPONENTS_DIRS_DICT[module]:
                    src = "/".join(("logmind", d))
                    dst = "/".join((Common.Paths.LOGMIND_PATH, d))

                    if backup_all:
                        print "Creating backup of", d
                        shutil.copytree(dst, "/".join((backup_dir,d)), ignore=shutil.ignore_patterns("log", "service"))

                    print "Upgrading", d
                    shutil.rmtree(dst)
                    shutil.copytree(src, dst)

            # Updating global version file.
            ver_file = "/".join(("logmind", "version"))
            shutil.copy(ver_file, Common.Paths.LOGMIND_PATH)

            return True

        except Exception, e:
            print "ERROR: ", e
            return False



    def do_install(self):
        print "Installing Logmind to", Common.Paths.LOGMIND_PATH

        print "Stopping services..."
        if self.stop_services():

            print "Backing-up config..."
            if self.backup_config():

                print "Copying files..."
                if self.copy_files():

                    print "Setting permissions..."
                    if self.set_permissions():

                        if self.set_attrs():

                            print "Restoring config..."
                            if self.restore_config():

                                    print "Starting services..."
                                    if self.start_services():
                                        print ShellColors.OKGREEN + "Logmind upgraded successfully to version " + Version.VERSION["GENERAL"] + "!" + ShellColors.ENDC


