#!/usr/bin/python

import os
import sys
import shutil
from subprocess import call, Popen, PIPE



LOGMIND_PATH = "/usr/local/logmind"


class ShellColors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'




es_conf_file = "/".join((LOGMIND_PATH, "elasticsearch", "config", "elasticsearch.yml"))
openmind_conf_file = "/".join((LOGMIND_PATH, "openmind", "GlobalConfig.rb"))
indexer_conf_file = "/".join((LOGMIND_PATH, "sixthsense", "config", "indexer.conf", "logmind-indexer.conf"))   
shipper_conf_file = "/".join((LOGMIND_PATH, "sixthsense", "config", "shipper.conf", "logmind-shipper.conf"))   
shipper_eventlog_conf_file = "/".join((LOGMIND_PATH, "sixthsense", "config", "shipper.conf", "eventlog-filters.conf"))      
shipper_syslog_conf_file = "/".join((LOGMIND_PATH, "sixthsense", "config", "shipper.conf", "syslog-endpoint.conf"))

components_dirs_dict = {
    "elasticsearch": ["elasticsearch"],
    "openmind": ["openmind", "rubystack"],
    "redis": ["redis"],
    "sixthsense": ["sixthsense"]
    }


#######################
#### M E T H O D S ####
#######################

def prompt(msg):
    res = ""
    while not res.strip().lower() in ["y", "n"]:
        res = raw_input(msg)

    return res


def user_input(msg):
    res = ""
    while not len(res) > 0:
        res = raw_input(msg)

    return res





def get_versions_dict():
    d = {}
    d["GENERAL"] = get_version("GENERAL")
    d["elasticsearch"] = get_version("elasticsearch")
    d["openmind"] = get_version("openmind")
    d["sixthsense"] = get_version("sixthsense")
    d["redis"] = get_version("redis")

    return d


def get_version(folder):
    try:
        if folder == "GENERAL":
            version_path = "/".join((LOGMIND_PATH, "version"))
        else:
            version_path = "/".join((LOGMIND_PATH, folder, "config", "version"))

        if os.path.exists(version_path):
            return open(version_path, "rb").read().strip()
        else:
            return 0

    except Exception, e:
        print "ERROR: ", e
        return -1

        

