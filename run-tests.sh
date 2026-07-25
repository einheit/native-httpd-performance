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

  if command -v sockstat >/dev/null 2>&1; then
    # FreeBSD native approach
    pid=$(sockstat -46l -P tcp -p 8080 | awk 'NR>1 {print $3}' | sort -u)
  elif command -v lsof >/dev/null 2>&1; then
    # Cross-platform / Linux fallback
    pid=$(lsof -t -i :8080)
  elif command -v fuser >/dev/null 2>&1; then
    # Linux fallback
    pid=$(fuser 8080/tcp 2>/dev/null)
  fi

  if [ -n "$pid" ]; then
    # Quote $pid to handle multiple space-separated PIDs safely
    kill -9 $pid 2>/dev/null
    sleep 1.5
  fi
}

echo "\n================================================================================"
echo " STAGE 2: RUNNING BENCHMARKS"
echo "================================================================================"

for i in run-httpd.*; do
    [ -e "$i" ] || continue
    base="${i#run-httpd.}"

    # --- LANGUAGE CHECK ---
    # Map the filename extension/suffix to the required system command
    case "$base" in
        bun)    REQ_CMD="bun" ;;
        node|js) REQ_CMD="node" ;;
        go)     REQ_CMD="go" ;;
        python|py) REQ_CMD="python3" ;;
        rb|ruby) REQ_CMD="ruby" ;;
        *)      REQ_CMD="" ;; # No check for unknown types
    esac

    # Skip if the required command is missing on the machine
    if [ -n "$REQ_CMD" ] && ! command -v "$REQ_CMD" >/dev/null 2>&1; then
        echo "[INFO] Skipping $i: '$REQ_CMD' is not installed."
        continue
    fi
    # --------------------------

    chmod +x "$i"
    
    for mode in standard keepalive; do
        if [ "$mode" = "keepalive" ]; then
            K_FLAG="-k"
            mode_lbl="Keep-Alive"
        else
            K_FLAG=""
            mode_lbl="Standard"
        fi
        
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

