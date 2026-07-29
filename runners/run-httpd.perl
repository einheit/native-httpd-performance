#!/bin/sh

if [ $# -gt 0 ]; then 
  port="$1"
else 
  port="8080"
fi

perl -MStarman -e 1
code=$?

if [ $code = 0 ]; then 
  echo "starting perl http server"
  starman --workers 8 --host 127.0.0.1 -p ${port} ../src/server.pl >/dev/null 2>&1
else
  echo "missing dependencies, perl http server not started"
  exit 1
fi

