#!/bin/sh

echo "================================================================================"
echo " PRE-COMPILATION"
echo "================================================================================"

OS=`uname -s`

for i in run-httpd.*; do
    [ -e "$i" ] || continue
    ext="${i#run-httpd.}"

    case "$ext" in
        go)
            echo "[COMPILE] Go -> bin-server_go"
            go build -ldflags="-s -w" -o bin-server_go main.go
            ;;
        rs)
            echo "[COMPILE] Rust -> bin-server_rs"
            rustc -O -o bin-server_rs main.rs
            ;;
        zig)
            echo "[COMPILE] Zig -> bin-server_zig"
            zig build-exe -O ReleaseFast --name bin-server_zig main.zig
            ;;
        c)
            echo "[COMPILE] C -> bin-server_c"
	    if [ $OS = 'Linux' ]; then
              cc -O3 -o bin-server_c server.c
	    elif [ $OS = 'FreeBSD' ]; then
	      cc -o bin-server_c server.c
	    fi
            ;;
        cr)
            echo "[COMPILE] Crystal -> bin-server_cr"
            crystal build --release -o bin-server_cr server.cr
            ;;
        bun|js|pl|py|raku|rb)
            # Scripts skip the build process completely
            echo "[SKIPPED] Interpreted script ($ext) requires no compilation."
            ;;
        *)
            echo "[WARNING] Unknown extension: $ext. Skipping build phase."
            ;;
    esac
done

