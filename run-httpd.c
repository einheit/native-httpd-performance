#!/bin/sh

# Compile with high optimization (-O3) and thread support
if [ ! -f ./server_c ] || [ server.c -nt ./server_c ]; then
    gcc -O3 -pthread -o server_c server.c
fi

exec ./server_c
