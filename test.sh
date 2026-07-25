#!/bin/sh
N=8192
TMP_DIR="tmp"

[ -d "$TMP_DIR" ] || mkdir "$TMP_DIR"
rm -f "$TMP_DIR"/*

# 1. Determine the best available health-check command (Strict Network Only)
if command -v curl >/dev/null 2>&1; then
    # -o /dev/null ensures we don't dump binary output data into the stream
    CHECK_CMD="curl -s -o /dev/null --fail --connect-timeout 1 http://127.0.0"
elif command -v wget >/dev/null 2>&1; then
    # --tries=1 blocks internal loops; --spider ensures no files save to disk
    CHECK_CMD="wget -q --spider --tries=1 --timeout=1 http://127.0.0"
else
    echo "Error: Neither curl nor wget is installed."
    exit 1
fi

cleanup_port() {
    pid=""
    if command -v lsof >/dev/null 2>&1; then
        pid=$(lsof -t -i :8080)
    elif command -v fuser >/dev/null 2>&1; then
        pid=$(fuser 8080/tcp 2>/dev/null)
    fi
    if [ -n "$pid" ]; then
        kill -9 $pid 2>/dev/null
        sleep 1.5
    fi
}

# ==============================================================================
# PHASE A: INTELLIGENT PRE-COMPILATION
# ==============================================================================
echo "================================================================================"
echo " STAGE 1: CONDITIONAL PRE-COMPILATION PHASE"
echo "================================================================================"

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
            gcc -O3 -o bin-server_c server.c
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

# ==============================================================================
# PHASE B: BENCHMARK EXECUTION LOOP
# ==============================================================================
echo "\n================================================================================"
echo " STAGE 2: RUNNING BENCHMARKS"
echo "================================================================================"

for i in run-httpd.*; do
    [ -e "$i" ] || continue
    base="${i#run-httpd.}"
    chmod +x "$i"
    
    for mode in standard keepalive; do
        if [ "$mode" = "keepalive" ]; then
            K_FLAG="-k"
            mode_lbl="Keep-Alive"
        else
            K_FLAG=""
            mode_lbl="Standard"
        fi
        
        cleanup_port


	        # Settle state before launching server
        cleanup_port

        clear_attempts=0
        while $CHECK_CMD >/dev/null 2>&1; do
          clear_attempts=$((clear_attempts + 1))
          if [ "$clear_attempts" -gt 5 ]; then
            echo "[WARNING] Port 8080 reporting busy via health check but clear via PID. Proceeding..."
            break
          fi
          echo "Waiting for port 8080 to clear..."
          sleep 0.5
        done
        
        echo "Launching $i ($mode_lbl)..."
        ./"$i" &
        SERVER_PID=$!
        
        TIMEOUT=10
        while ! $CHECK_CMD >/dev/null 2>&1; do
            sleep 0.5
            TIMEOUT=$((TIMEOUT - 1))
            if [ "$TIMEOUT" -le 0 ]; then
                echo "Error: Server $i failed to bind to port 8080."
                kill -9 "$SERVER_PID" 2>/dev/null
                continue 2
            fi
        done
        
        sleep 1.5
        
        for c in 1 8 64; do
            ab $K_FLAG -n $N -c $c http://127.0.0.1:8080/ 2>/dev/null | \
                awk -F'[^0-9.]+' '/Requests per second/ {print $2}' > "$TMP_DIR/${base}_${mode}-${c}.out"
            sleep 0.2
        done
        
        kill -9 "$SERVER_PID" 2>/dev/null
        cleanup_port
    done
done

# ==============================================================================
# PHASE C: REPORT GENERATION
# ==============================================================================
echo "\n================================================================================"
echo "BENCHMARK RESULTS SUMMARY (Requests per second, sorted by 64 Clients descending)"
echo "================================================================================"
echo "| Implementation | Mode       | 1 Client      | 8 Clients     | 64 Clients     |"
echo "|----------------|------------|---------------|---------------|----------------|"

for out_file in "$TMP_DIR"/*-1.out; do
    [ -e "$out_file" ] || continue
    
    runner="${out_file#$TMP_DIR/}"
    runner="${runner%-1.out}"
    impl="${runner%_*}"
    mode="${runner##*_}"
    
    rps_1=$(cat "$TMP_DIR/${runner}-1.out" 2>/dev/null)
    rps_8=$(cat "$TMP_DIR/${runner}-8.out" 2>/dev/null)
    rps_64=$(cat "$TMP_DIR/${runner}-64.out" 2>/dev/null)
    
    printf "| %-14s | %-10s | %13.2f | %13.2f | %14.2f |\n" \
        "$impl" "$mode" "${rps_1:-0}" "${rps_8:-0}" "${rps_64:-0}"
done | sort -t'|' -k6 -n -r

echo "================================================================================"

