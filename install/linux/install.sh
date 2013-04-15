#!/bin/bash
LOGMIND_PATH=/usr/local/logmind
echo "Installing Logmind to $LOGMIND_PATH"
# 1. copy logmind directory to the target
mkdir -p $LOGMIND_PATH
cp -R -f ./logmind/* $LOGMIND_PATH
cp -R -f ./daemontools-0.76 $LOGMIND_PATH
# 2. set the correct mode for the files
chmod 755 $LOGMIND_PATH/elasticsearch/service/run
chmod 755 $LOGMIND_PATH/elasticsearch/service/log/run
chmod 755 $LOGMIND_PATH/redis/service/run
chmod 755 $LOGMIND_PATH/redis/service/log/run
chmod 755 $LOGMIND_PATH/openmind/service/run
chmod 755 $LOGMIND_PATH/openmind/service/log/run
chmod 755 $LOGMIND_PATH/sixthsense/sixthsense.sh
chmod 755 $LOGMIND_PATH/sixthsense/indexer/service/run
chmod 755 $LOGMIND_PATH/sixthsense/indexer/service/log/run
chmod 755 $LOGMIND_PATH/sixthsense/shipper/service/run
chmod 755 $LOGMIND_PATH/sixthsense/shipper/service/log/run
chmod 755 $LOGMIND_PATH/daemontools-0.76/package/upgrade
chmod 755 $LOGMIND_PATH/daemontools-0.76/package/run
# 3. set other attributes
# 4. install/upgrade daemon tools service
pushd $LOGMIND_PATH/daemontools-0.76
package/upgrade
package/run
popd
# 5. create symbolic links for the service directories
pushd /service
ln -s $LOGMIND_PATH/elasticsearch/service logmind-elasticsearch
ln -s $LOGMIND_PATH/redis/service logmind-redis
ln -s $LOGMIND_PATH/openmind/service logmind-openmind
ln -s $LOGMIND_PATH/sixthsense/indexer/service logmind-indexer
ln -s $LOGMIND_PATH/sixthsense/shipper/service logmind-shipper
popd
echo "Logmind was installed successfully"

