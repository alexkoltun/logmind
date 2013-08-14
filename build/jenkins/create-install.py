#!/usr/bin/python
import sys

dir_name = sys.argv[1]
f = open("/logmind/build/build/jenkins/install.sh", "wb")
f.writelines(["#!/bin/sh", "\n", "/".join(("", dir_name, "install")) + "\"$@\""])
f.close()

