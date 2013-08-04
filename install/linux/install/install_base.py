import os
import sys

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
        


    def set_attrs(self):
        return True

