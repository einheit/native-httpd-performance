#!/bin/sh

go=`which ab`
code=$?

[ $code -ne 0 ] && { echo "apachebench (normally included with apache) must be installed"; exit 1; }

N=8192

TMP_DIR="tmp"
[ -d "$TMP_DIR" ] || mkdir "$TMP_DIR"
rm -f "$TMP_DIR"/*

OS=`uname -s`

cleanup_port() {
    pid=""
    if command -v sockstat >/dev/null 2>&1; then
        pid=$(sockstat -46l -P tcp -p 8080 | awk 'NR>1 {print $3}' | sort -u)
    elif command -v lsof >/dev/null 2>&1; then
        pid=$(lsof -t -i :8080)
    elif command -v fuser >/dev/null 2>&1; then
        pid=$(fuser 8080/tcp 2>/dev/null)
    fi
    if [ -n "$pid" ]; then
        kill -9 $pid 2>/dev/null
        sleep 1.5
    fi
}

echo
echo "================================================================================"
echo " STAGE 2: RUNNING BENCHMARKS"
echo "================================================================================"

for i in run-httpd.*; do
    [ -e "$i" ] || continue
    base="${i#run-httpd.}"
    cleanup_port

    case "$base" in
        bun) REQ_CMD="bun" ;;
        node|js) REQ_CMD="node" ;;
        go) REQ_CMD="go" ;;
        python|py) REQ_CMD="python3" ;;
        rb|ruby) REQ_CMD="ruby" ;;
        raku|raku) REQ_CMD="raku" ;;
        *) REQ_CMD="" ;;
    esac

    if [ -n "$REQ_CMD" ] && ! command -v "$REQ_CMD" >/dev/null 2>&1; then
        echo "[INFO] Skipping $i: '$REQ_CMD' is not installed."
        continue
    fi

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
        echo "Launching $i ($mode_lbl)..."
        ./"$i" &
        SERVER_PID=$!
        
        sleep 3

        for c in 1 8 64; do
            ab $K_FLAG -n $N -c $c http://127.0.0.1:8080/ 2>/dev/null | \
            awk -F'[^0-9.]+' '/Requests per second/ {print $2}' > "$TMP_DIR/${base}_${mode}-${c}.out"
            sleep 0.2
        done

        kill -9 "$SERVER_PID" 2>/dev/null
        cleanup_port
    done
done

