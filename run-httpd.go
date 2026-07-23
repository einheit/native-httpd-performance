#!/bin/sh
# Compile on the fly, then exec the built binary

go build -o server_go main.go
exec ./server_go

