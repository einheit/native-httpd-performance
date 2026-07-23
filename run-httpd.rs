#!/bin/sh
# Build in release mode for maximum speed, then exec the binary
rustc -O main.rs -o server_rust
exec ./server_rust

