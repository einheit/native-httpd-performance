#!/bin/sh

plackup -s Starman --workers 8 -p 8080 app.psgi
