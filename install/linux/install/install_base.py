import os
import sys
import shutil
from subprocess import call, Popen, PIPE

from common import Common


class InstallBase:

    def do_install(self):
        raise NotImplementedError
    
    
    def set_permissions(self):

        try:
            os.chmod(Common.Paths.LOGMIND_PATH + "/elasticsearch/service/run", 0755)
            os.chmod(Common.Paths.LOGMIND_PATH + "/elasticsearch/service/log/run", 0755)
            os.chmod(Common.Paths.LOGMIND_PATH + "/elasticsearch/bin/elasticsearch", 0755)
            os.chmod(Common.Paths.LOGMIND_PATH + "/redis/service/run", 0755)
            os.chmod(Common.Paths.LOGMIND_PATH + "/redis/service/log/run", 0755)
            os.chmod(Common.Paths.LOGMIND_PATH + "/redis/redis-server", 0755)
            os.chmod(Common.Paths.LOGMIND_PATH + "/redis/redis-cli", 0755)
            os.chmod(Common.Paths.LOGMIND_PATH + "/openmind/service/run", 0755)
            os.chmod(Common.Paths.LOGMIND_PATH + "/openmind/service/log/run", 0755)
            os.chmod(Common.Paths.LOGMIND_PATH + "/sixthsense/sixthsense.sh", 0755)
            os.chmod(Common.Paths.LOGMIND_PATH + "/sixthsense/indexer/service/run", 0755)
            os.chmod(Common.Paths.LOGMIND_PATH + "/sixthsense/indexer/service/log/run", 0755)
            os.chmod(Common.Paths.LOGMIND_PATH + "/sixthsense/shipper/service/run", 0755)
            os.chmod(Common.Paths.LOGMIND_PATH + "/sixthsense/shipper/service/log/run", 0755)
            os.chmod(Common.Paths.LOGMIND_PATH + "/daemontools-0.76/package/upgrade", 0755)
            os.chmod(Common.Paths.LOGMIND_PATH + "/daemontools-0.76/package/run", 0755)
            os.chmod(Common.Paths.LOGMIND_PATH + "/daemontools-0.76/package/run-inittab", 0755)
            os.chmod(Common.Paths.LOGMIND_PATH + "/daemontools-0.76/package/run-upstart", 0755)
            os.chmod(Common.Paths.LOGMIND_PATH + "/daemontools-0.76/package/run.inittab", 0755)
            
            commands_path = Common.Paths.LOGMIND_PATH + "/daemontools-0.76/command"
            commands = os.listdir(commands_path)
            for c in commands:
                os.chmod("/".join((commands_path, c)), 0755)

            return True

        except Exception, e:
            print "ERROR: ", e
            return False
        
    
    
    def set_permissions_client(self):

        try:
            os.chmod(Common.Paths.LOGMIND_PATH + "/sixthsense/sixthsense.sh", 0755)
            os.chmod(Common.Paths.LOGMIND_PATH + "/sixthsense/shipper/service/run", 0755)
            os.chmod(Common.Paths.LOGMIND_PATH + "/sixthsense/shipper/service/log/run", 0755)
            os.chmod(Common.Paths.LOGMIND_PATH + "/daemontools-0.76/package/upgrade", 0755)
            os.chmod(Common.Paths.LOGMIND_PATH + "/daemontools-0.76/package/run", 0755)
            os.chmod(Common.Paths.LOGMIND_PATH + "/daemontools-0.76/package/run-inittab", 0755)
            os.chmod(Common.Paths.LOGMIND_PATH + "/daemontools-0.76/package/run-upstart", 0755)
            os.chmod(Common.Paths.LOGMIND_PATH + "/daemontools-0.76/package/run.inittab", 0755)
            
            commands_path = Common.Paths.LOGMIND_PATH + "/daemontools-0.76/command"
            commands = os.listdir(commands_path)
            for c in commands:
                os.chmod("/".join((commands_path, c)), 0755)

            return True

        except Exception, e:
            print "ERROR: ", e
            return False
        


    def set_attrs(self):
        return True



    def inst_daemon(self, curdir):

        try:
            os.chdir("/".join((Common.Paths.LOGMIND_PATH, "daemontools-0.76")))

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



    def start_services(self):

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



    def stop_services_upgrade(self):
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
        

    def start_services_upgrade(self):
        try:
            success = call(["/command/svcs-u"]) == 0

            if not success:
                print "Error while starting services."
            
            return success

        except Exception, e:
            print "ERROR: ", e
            return False



    def copy_files_upgrade(self):
        try:
            upgrade_modules = self.get_upgrade_modules_list()
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

