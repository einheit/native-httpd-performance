#!/bin/sh

# dependencies - plackup and Starman

command -v plackup
code1=$?
perl -MStarman -e 1
code2=$?

if [ $code1 = 0 ] && [ $code2 = 0 ]; then 
  echo "starting perl http server"
  plackup -s Starman --workers 8 --host 127.0.0.1 -p 8080 ../src/server.pl >/dev/null 2>&1
else
  echo "missing dependencies, perl http server not started"
  exit 1
fi

