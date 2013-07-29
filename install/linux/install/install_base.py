import os
import sys

execfile("/".join((os.path.dirname(os.path.realpath(sys.argv[0])), "install", "common.py")))


#######################
#### M E T H O D S ####
#######################


def set_permissions():

    try:
        os.chmod(LOGMIND_PATH + "/elasticsearch/service/run", 0755)
        os.chmod(LOGMIND_PATH + "/elasticsearch/service/log/run", 0755)
        os.chmod(LOGMIND_PATH + "/elasticsearch/bin/elasticsearch", 0755)
        os.chmod(LOGMIND_PATH + "/redis/service/run", 0755)
        os.chmod(LOGMIND_PATH + "/redis/service/log/run", 0755)
        os.chmod(LOGMIND_PATH + "/redis/redis-server", 0755)
        os.chmod(LOGMIND_PATH + "/redis/redis-cli", 0755)
        os.chmod(LOGMIND_PATH + "/openmind/service/run", 0755)
        os.chmod(LOGMIND_PATH + "/openmind/service/log/run", 0755)
        os.chmod(LOGMIND_PATH + "/sixthsense/sixthsense.sh", 0755)
        os.chmod(LOGMIND_PATH + "/sixthsense/indexer/service/run", 0755)
        os.chmod(LOGMIND_PATH + "/sixthsense/indexer/service/log/run", 0755)
        os.chmod(LOGMIND_PATH + "/sixthsense/shipper/service/run", 0755)
        os.chmod(LOGMIND_PATH + "/sixthsense/shipper/service/log/run", 0755)
        os.chmod(LOGMIND_PATH + "/daemontools-0.76/package/upgrade", 0755)
        os.chmod(LOGMIND_PATH + "/daemontools-0.76/package/run", 0755)
        os.chmod(LOGMIND_PATH + "/daemontools-0.76/package/run-inittab", 0755)
        os.chmod(LOGMIND_PATH + "/daemontools-0.76/package/run-upstart", 0755)
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

