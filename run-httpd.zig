#!/bin/sh

zig build-exe main.zig -O ReleaseFast -femit-bin=server_zig

exec ./server_zig

