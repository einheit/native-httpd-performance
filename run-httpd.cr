#!/bin/sh

echo "building crystal executable"
crystal build --release -o server_cr server.cr
exec ./server_cr
sleep 3 # crystal http server takes a minute to spin up
