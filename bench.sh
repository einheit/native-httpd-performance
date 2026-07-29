#!/bin/sh

INI="params.ini"

# 1. Verify ApacheBench is installed before doing anything else
AB_BIN=$(command -v ab)
if [ $? -ne 0 ]; then
    echo "ERROR: apachebench (ab) must be installed to run benchmarks."
    exit 1
fi

# 2. Source params.ini to load variables ($OS, $rundir, $TMP_DIR, $LOW_C, etc.)
if [ -r "$INI" ]; then
    . "./$INI"
else
    echo "params file missing"
    exit 1
fi

# Ensure critical variables are not empty
[ -d "$TMP_DIR" ] || mkdir "$TMP_DIR"
rm -f "$TMP_DIR"/*

cleanup_port() {
    pid=""
    if [ "$OS" = "Linux" ] || [ "$OS" = "FreeBSD" ]; then
        if command -v lsof >/dev/null 2>&1; then
            pid=$(lsof -t -i :${PORT})
        elif command -v sockstat >/dev/null 2>&1; then
            pid=$(sockstat -46l -P tcp -p ${PORT} | awk 'NR>1 {print $3}' | sort -u)
        elif command -v fuser >/dev/null 2>&1; then
            pid=$(fuser ${PORT}/tcp 2>/dev/null)
        fi
    elif [ "$OS" = "Darwin" ]; then # macOS
        if command -v lsof >/dev/null 2>&1; then
            pid=$(lsof -t -i :${PORT})
        fi

    elif [ "$OS" = "OpenBSD" ]; then
        if command -v fstat >/dev/null 2>&1; then
            # Looks in fields 3 and 4, extracting only numeric PIDs
            pid=$(fstat | grep ':8080' | awk '{
                if ($3 ~ /^[0-9]+$/) print $3;
                else if ($4 ~ /^[0-9]+$/) print $4;
            }' | sort -u)
        fi
    fi

    if [ -n "$pid" ]; then
        for p in $pid; do
            kill -9 "$p" >/dev/null 2>&1
        done
        sleep 1.5
    fi
}

echo
echo "================================================================================"
echo " STAGE 2: RUNNING BENCHMARKS (WITH AVERAGING)"
echo "================================================================================"

cd "$rundir" || exit 1

for i in run-httpd.*; do
    [ -e "$i" ] || continue
    base="${i#run-httpd.}"
    cleanup_port

    case "$base" in
        bun) REQ_CMD="bun" ;;
        c) REQ_CMD="cc" ;;
        crystal) REQ_CMD="crystal" ;;
        go) REQ_CMD="go" ;;
        node|js) REQ_CMD="node" ;;
        perl|pl) REQ_CMD="starman" ;;
        powershell|ps1) REQ_CMD="pwsh" ;;
        python|py) REQ_CMD="python3" ;;
        raku) REQ_CMD="raku" ;;
        rb|ruby) REQ_CMD="ruby" ;;
        rust) REQ_CMD="rustc" ;;
        zig) REQ_CMD="zig" ;;
        *) REQ_CMD="" ;;
    esac

    if [ -n "$REQ_CMD" ] && ! command -v "$REQ_CMD" >/dev/null 2>&1; then
        echo "[INFO] Skipping $i: '$REQ_CMD' runtime is not installed."
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
        
        # Start server background process tree safely using quotes
        "./${i}" &
        SERVER_PID=$!
        
        sleep 3

        for c in $LOW_C $MID_C $HIGH_C; do
            echo " -> Testing Concurrency -$c ($RUNS_PER_TEST iterations)..."
            
            raw_runs_file="$TMP_DIR/${base}_${mode}-${c}.raw"
            rm -f "$raw_runs_file"

            run_idx=1
            while [ "$run_idx" -le "$RUNS_PER_TEST" ]; do
                ab_raw_output=$(ab $K_FLAG -n $N -c $c http://127.0.0.1:${PORT}/ 2>&1)
                
                # Cross-platform safe parsing: Targets the 4th space-separated field
                rps=$(echo "$ab_raw_output" | awk '/Requests per second:/ {print $4}')

                if [ -n "$rps" ]; then
                    echo "$rps" >> "$raw_runs_file"
                else
                    echo "DEBUG: Run $run_idx failed. ApacheBench output was:" >&2
                    echo "--------------------------------------------------" >&2
                    echo "$ab_raw_output" | while read -r line; do echo "  $line"; done >&2
                    echo "--------------------------------------------------" >&2
                fi

                sleep 0.3
                run_idx=$((run_idx + 1))
            done

            # Mathematical Aggregator: Universal POSIX array sorting and math
            if [ -f "$raw_runs_file" ]; then
                awk '
                {
                    gsub(/\r/, "", $1)
                    if ($1 > 0) {
                        arr[count++] = $1
                    }
                }
                END {
                    if (count >= 3) {
                        for (i = 0; i < count; i++) {
                            for (j = i + 1; j < count; j++) {
                                if (arr[i] > arr[j]) {
                                    tmp = arr[i]; arr[i] = arr[j]; arr[j] = tmp
                                }
                            }
                        }
                        for (i = 1; i < count - 1; i++) {
                            sum += arr[i]
                        }
                        printf "%.2f\n", sum / (count - 2)
                    } else if (count > 0) {
                        for (i = 0; i < count; i++) sum += arr[i]
                        printf "%.2f\n", sum / count
                    } else {
                        print "0.00"
                    }
                } ' "$raw_runs_file" > "$TMP_DIR/${base}_${mode}-${c}.out"
                
                rm -f "$raw_runs_file"
            else
                echo "0.00" > "$TMP_DIR/${base}_${mode}-${c}.out"
            fi
        done

        if kill -0 "$SERVER_PID" >/dev/null 2>&1; then
            kill -9 "$SERVER_PID" >/dev/null 2>&1
        fi
        cleanup_port
    done
done

