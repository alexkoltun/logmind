#!/usr/bin/python

import sys


BASE_PATH = "/logmind/build"

VERSION_FILES = ["elasticsearch/config/version", "install/linux/install/version.py", "install/linux/logmind/version", "openmind/platform/linux/config/version", "redis/platform/linux/config/version", "sixthsense/platform/linux/config/version", "openmind/views/main.erb"]

LOGMIND_VERSION = open(sys.argv[1], "rb").read().strip()



for f in VERSION_FILES:
	path = "/".join((BASE_PATH, f))
	content = open(path, "rb").read()
	
	content = content.replace("[LOGMIND_VERSION]", LOGMIND_VERSION)
	
	nf = open(path, "wb")
	nf.write(content)
	nf.close()
	
