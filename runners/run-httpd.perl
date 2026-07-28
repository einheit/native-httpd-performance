#!/bin/sh

# dependencies - plackup and Starman

plackup -s Starman --workers 8 --host 127.0.0.1 -p 8080 ../src/server.pl >/dev/null 2>&1

