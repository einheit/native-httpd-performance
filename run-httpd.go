#!/bin/sh
# Compile on the fly, then exec the built binary

go build -o httpd_go main.go
exec ./httpd_go

