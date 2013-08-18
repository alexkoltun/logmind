#!/usr/bin/python

import os
import sys
import shutil
from subprocess import call, Popen, PIPE
import time


class Common:
    
    PORTS_TO_TEST = [80, 514, 6379, 8751]

    class Paths:

        LOGMIND_PATH = "/usr/local/logmind"
        
        ES_CONF_FILE = "/".join((LOGMIND_PATH, "elasticsearch", "config", "elasticsearch.yml"))
        OPENMIND_CONF_FILE = "/".join((LOGMIND_PATH, "openmind", "GlobalConfig.rb"))
        INDEXER_CONF_FILE = "/".join((LOGMIND_PATH, "sixthsense", "config", "indexer.conf", "logmind-indexer.conf"))   
        SHIPPER_CONF_FILE = "/".join((LOGMIND_PATH, "sixthsense", "config", "shipper.conf", "logmind-shipper.conf"))   
        SHIPPER_EVENTLOG_CONF_FILE = "/".join((LOGMIND_PATH, "sixthsense", "config", "shipper.conf", "eventlog-filters.conf"))      
        SHIPPER_SYSLOG_CONF_FILE = "/".join((LOGMIND_PATH, "sixthsense", "config", "shipper.conf", "syslog-endpoint.conf"))

        COMPONENTS_DIRS_DICT = {
            "elasticsearch": ["elasticsearch/bin", "elasticsearch/config", "elasticsearch/lib", "elasticsearch/plugins"],
            "openmind": ["openmind", "rubystack"],
            "redis": ["redis"],
            "sixthsense": ["sixthsense/cep", "sixthsense/config", "sixthsense/indexer", "sixthsense/patterns", "sixthsense/shipper", "sixthsense/samples", "sixthsense/logstash.jar", "sixthsense/sixthsense.sh"]
            }


    #######################
    #### M E T H O D S ####
    #######################

    @staticmethod 
    def prompt(msg):
        res = ""
        while not res.strip().lower() in ["y", "n"]:
            res = raw_input(msg)

        return res


    @staticmethod
    def user_input(msg):
        res = ""
        while not len(res) > 0:
            res = raw_input(msg)

        return res


    @staticmethod
    def get_versions_dict():
        d = {}
        d["GENERAL"] = Common.get_version("GENERAL")
        d["elasticsearch"] = Common.get_version("elasticsearch")
        d["openmind"] = Common.get_version("openmind")
        d["sixthsense"] = Common.get_version("sixthsense")
        d["redis"] = Common.get_version("redis")

        return d


    @staticmethod
    def get_version(folder):
        try:
            if folder == "GENERAL":
                version_path = "/".join((Common.Paths.LOGMIND_PATH, "version"))
            else:
                version_path = "/".join((Common.Paths.LOGMIND_PATH, folder, "config", "version"))

            if os.path.exists(version_path):
                return open(version_path, "rb").read().strip()
            else:
                return 0

        except Exception, e:
            print "ERROR: ", e
            return -1

            


class ShellColors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
