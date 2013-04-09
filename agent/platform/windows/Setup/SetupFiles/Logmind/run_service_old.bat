IF  NOT EXIST "%~dp0logstash" GOTO extractJar
ELSE GOTO run

:extractJar
echo extracting
START /WAIT 7z.exe x -ologstash logstash-1.1.9-monolithic.jar
GOTO run

:run
echo running
"%~dp0java\jre6\bin\java.exe" -cp logstash logstash.runner agent -f pipe.conf --log log.txt -v