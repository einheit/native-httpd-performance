#!/bin/sh

plackup -s Starman --workers 8 -p 8080 server.pl  > /dev/null 2>&1
