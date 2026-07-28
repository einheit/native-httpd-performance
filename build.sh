#!/bin/sh

echo "================================================================================"
echo " STAGE 1: PRE-COMPILATION"
echo "================================================================================"

OS=`uname -s`
rundir="runners"
srcdir="src"

for i in `find ${rundir} -name "run-httpd*" | awk -F'/' '{ print $2 }'`
  do
    [ -e "${rundir}/$i" ] || continue
    ext="${i#run-httpd.}"

    case "$ext" in
        go)
            echo "[COMPILE] Go -> bin-server_go"
            go build -ldflags="-s -w" -o ${rundir}/bin-server_go ${srcdir}/main.go
            ;;
        rs|rust)
            echo "[COMPILE] Rust -> bin-server_rs"
            rustc -O -o ${rundir}/bin-server_rs ${srcdir}/main.rs
            ;;
        zig)
            echo "[COMPILE] Zig -> bin-server_zig"
            zig build-exe -O ReleaseFast --name bin-server_zig ${srcdir}/main.zig
	    mv bin-server_zig $rundir
            ;;
        c)
            echo "[COMPILE] C -> bin-server_c"
              cc -O3 -o ${rundir}/bin-server_c ${srcdir}/server.c
            ;;
        cr|crystal)
            echo "[COMPILE] Crystal -> bin-server_cr"
            crystal build --release -o ${rundir}/bin-server_cr ${srcdir}/server.cr
            ;;
        bun|js|pl|perl|powershell|ps1|python|py|raku|ruby|rb)
            # Scripts skip the build process completely
            echo "[SKIPPED] Interpreted script ($ext) requires no compilation."
            ;;
        *)
            echo "[WARNING] Unknown extension: $ext. Skipping build phase."
            ;;
    esac
done

