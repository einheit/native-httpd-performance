#!/bin/sh

echo "building crystal executable"
crystal build --release -o server.cr httpd.cr
exec ./server.cr
sleep 3 # crystal http server takes a minute to spin up
