@echo off
echo Starting Logmind agent...
pushd %~dp0
"%~dp0Java\jre6\bin\java.exe" -jar "%~dp0logstash.jar" agent -f pipe.conf --log log.txt -v
popd
Rem java -cp logstash logstash.runner agent -f pipe.conf --log log.txt -v
