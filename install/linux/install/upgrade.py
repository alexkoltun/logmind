#!/usr/bin/python

import os
import sys

execfile("/".join((os.path.dirname(os.path.realpath(sys.argv[0])), "install", "install_base.py")))
execfile("/".join((os.path.dirname(os.path.realpath(sys.argv[0])), "install", "version.py")))


#######################
#### M E T H O D S ####
#######################

def stop_services_upgrade():
    import time
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
    

def start_services_upgrade():
    try:
        success = call(["/command/svcs-u"]) == 0

        if not success:
            print "Error while starting services."
        
        return success

    except Exception, e:
        print "ERROR: ", e
        return False

    

def backup_config():
    try:
        config_dir = "/".join((LOGMIND_PATH, "backup", "config"))
        if not os.path.exists(config_dir):
            os.makedirs(config_dir)
        else:
            shutil.rmtree(config_dir)
            os.makedirs(config_dir)
        
        shutil.copy(es_conf_file, config_dir)
        shutil.copy(openmind_conf_file, config_dir)
        shutil.copy(indexer_conf_file, config_dir)
        shutil.copy(shipper_conf_file, config_dir)
        shutil.copy(shipper_eventlog_conf_file, config_dir)
        shutil.copy(shipper_syslog_conf_file, config_dir)

        return True

    except Exception, e:
        print "ERROR: ", e
        return False


def restore_config():

    try:
        config_dir = "/".join((LOGMIND_PATH, "backup", "config"))
        if not os.path.exists(config_dir):
            os.makedirs(config_dir)
        
        shutil.copy("/".join((config_dir, "elasticsearch.yml")), es_conf_file)
        shutil.copy("/".join((config_dir, "GlobalConfig.rb")), openmind_conf_file)
        shutil.copy("/".join((config_dir, "logmind-indexer.conf")), indexer_conf_file)
        shutil.copy("/".join((config_dir, "logmind-shipper.conf")), shipper_conf_file)
        shutil.copy("/".join((config_dir, "eventlog-filters.conf")), shipper_eventlog_conf_file)
        shutil.copy("/".join((config_dir, "syslog-endpoint.conf")), shipper_syslog_conf_file)

        return True

    except Exception, e:
        print "ERROR: ", e
        return False


def copy_files_upgrade():
    try:
        upgrade_modules = sys.argv[sys.argv.index("-upgrade-only") + 1].split(",") if "-upgrade-only" in sys.argv else ["elasticsearch","openmind","sixthsense","redis"]
        backup_all = "-backup-all" in sys.argv
        ver_dict = get_versions_dict()

        backup_dir = "/".join((LOGMIND_PATH, "backup", "components"))
        if not os.path.exists(backup_dir):
            os.makedirs(backup_dir)
        else:
            shutil.rmtree(backup_dir)
            os.makedirs(backup_dir)

        for module in upgrade_modules:
            module = module.strip()
            print "Upgrading " + module + " from version '" + str(ver_dict[module]) + "' to version '" + str(version[module]) + "'"

            for d in components_dirs_dict[module]:
                src = "/".join(("logmind", d))
                dst = "/".join((LOGMIND_PATH, d))

                if backup_all:
                    print "Creating backup of", d
                    shutil.copytree(dst, "/".join((backup_dir,d)), ignore=shutil.ignore_patterns("log", "service"))

                print "Upgrading", d
                shutil.rmtree(dst)
                shutil.copytree(src, dst)

        return True

    except Exception, e:
        print "ERROR: ", e
        return False


#######################
#### U P G R A D E ####
#######################

print "Installing Logmind to", LOGMIND_PATH

print "Stopping services..."
if stop_services_upgrade():

    print "Backing-up config..."
    if backup_config():

        print "Copying files..."
        if copy_files_upgrade():

            print "Setting permissions..."
            if set_permissions():

                if set_attrs():

                    print "Restoring config..."
                    if restore_config():

                            print "Starting services..."
                            if start_services_upgrade():
                                print ShellColors.OKGREEN + "Logmind upgraded successfully to version " + version["GENERAL"] + "!" + ShellColors.ENDC


