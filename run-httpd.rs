#!/bin/sh
# Build in release mode for maximum speed, then exec the binary
rustc -O main.rs -o httpd_rust
exec ./httpd_rust

