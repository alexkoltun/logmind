#!/usr/bin/python
import sys

dir_name = sys.argv[1]
install_type = sys.argv[2] # server, server-upgrade, client, client-upgrade
f = open("/logmind/build/build/jenkins/install" + install_type + ".sh", "wb")
f.writelines(["#!/bin/sh", "\n", "/".join(("", dir_name, "install")) + " "])

if install_type == "server":
	f.write("-type server")
elif install_type == "server-upgrade":
	f.write("-type server -mode upgrade -backup")
elif install_type == "client":
	f.write("-type client")
elif install_type == "server":
	f.write("-type client -mode upgrade -backup")

f.close()

