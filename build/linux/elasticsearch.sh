ES_VERSION="0.90.0.RC1"

mkdir -p /usr/local/logmindbuild/install/logmind/elasticsearch
wget "https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-$ES_VERSION.tar.gz" -O elasticsearch.tar.gz
tar -zxvf elasticsearch.tar.gz
# copy the binaries
cp -R -f elasticsearch-$ES_VERSION/* /usr/local/logmindbuild/install/logmind/elasticsearch
# copy configuration additions, specific for current platform
cp -R -f /usr/local/logmindbuild/elasticsearch/platform/linux/* /usr/local/logmindbuild/install/logmind/elasticsearch

