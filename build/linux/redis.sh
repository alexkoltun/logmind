REDIS_VERSION="2.6.11"

mkdir -p /usr/local/logmindbuild/install/logmind/elasticsearch
wget "http://redis.googlecode.com/files/redis-$REDIS_VERSION.tar.gz" -O redis.tar.gz
tar -zxvf redis.tar.gz
pushd "redis-$REDIS_VERSION"
make
# copy the binaries
cp -R -f src/redis-server /usr/local/logmindbuild/install/logmind/redis
popd
# copy configuration additions, specific for current platform
cp -R -f /usr/local/logmindbuild/redis/platform/linux/* /usr/local/logmindbuild/install/logmind/redis
