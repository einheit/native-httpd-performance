#!/bin/sh
N=8192

# directory for temporary output results
[ -d tmp ] || mkdir tmp

# 1. Determine the best available health-check command
if command -v curl >/dev/null 2>&1; then
    CHECK_CMD="curl -s --connect-timeout 1 http://localhost:8080/"
elif command -v wget >/dev/null 2>&1; then
    CHECK_CMD="wget -q --spider -T 1 http://localhost:8080/"
else
    echo "Error: Neither curl nor wget is installed."
    exit 1
fi

# 2. Define cross-platform port cleanup function
cleanup_port() {
    echo "Ensuring port 8080 is clear..."
    if command -v lsof >/dev/null 2>&1; then
        pid=$(lsof -t -i :8080)
    elif command -v fuser >/dev/null 2>&1; then
        pid=$(fuser 8080/tcp 2>/dev/null)
    fi
    if [ -n "$pid" ]; then
        echo "Port 8080 is busy (PID: $pid). Cleaning up..."
        kill -9 $pid 2>/dev/null
        sleep 1
    fi
}

# 3. Main Loop
for i in run-http*; do
    [ -e "$i" ] || continue
    
    # Strip "run-httpd." to get just the extension/language (e.g. "pl", "js", "cr")
    base="${i#run-httpd.}"
    
    # Run tests for both Close (standard) and Keep-Alive configurations
    for mode in standard keepalive; do
        if [ "$mode" = "keepalive" ]; then
            K_FLAG="-k"
            mode_lbl="Keep-Alive"
        else
            K_FLAG=""
            mode_lbl="Standard"
        fi

        cleanup_port
        ./"$i" &
        SERVER_PID=$!
        echo "Waiting for $i ($mode_lbl) to initialize..."
        
        TIMEOUT=20 # 20 * 0.5s = 10s maximum timeout
        while ! $CHECK_CMD >/dev/null 2>&1; do
            sleep 0.5
            TIMEOUT=$((TIMEOUT - 1))
            if [ "$TIMEOUT" -le 0 ]; then
                echo "Error: Server $i failed to start on time."
                kill "$SERVER_PID" 2>/dev/null
                continue 2
            fi
        done
        
        echo "Server responded to health check. Settling runtime environment..."
        sleep 3
        echo "Starting benchmarks ($mode_lbl)..."
        
        # Run benchmarks and save to tmp directory using a combined filename pattern
        ab $K_FLAG -n $N -c 1 http://localhost:8080/ 2>/dev/null | grep 'Requests per second' > "tmp/${base}_${mode}-1.out"
        sleep 1
        ab $K_FLAG -n $N -c 8 http://localhost:8080/ 2>/dev/null | grep 'Requests per second' > "tmp/${base}_${mode}-8.out"
        sleep 1
        ab $K_FLAG -n $N -c 64 http://localhost:8080/ 2>/dev/null | grep 'Requests per second' > "tmp/${base}_${mode}-64.out"
        sleep 1
        
        # Clean up background process cleanly
        kill "$SERVER_PID" 2>/dev/null
        cleanup_port
        sleep 1
    done
done

# 4. Generate Sorted Performance Comparison Table
echo "\n================================================================================"
echo "                            BENCHMARK RESULTS SUMMARY"
echo "================================================================================"
echo "| Implementation | Mode       | 1 Client      | 8 Clients     | 64 Clients     |"
echo "|----------------|------------|---------------|---------------|----------------|"
for out_file in tmp/*-1.out; do
    [ -e "$out_file" ] || continue
    
    # Extract unique runner string by stripping tmp/ path and -1.out suffix
    # Example format of $runner: "js_standard" or "cr_keepalive"
    runner="${out_file#tmp/}"
    runner="${runner%-1.out}"
    
    # Split the implementation name and the mode
    impl="${runner%_*}"
    mode="${runner##*_}"
    
    # Default empty outputs to "N/A" if a metric failed to extract
    rps_1=$(grep "Requests per second" "tmp/${runner}-1.out" | awk '{print $4}')
    rps_8=$(grep "Requests per second" "tmp/${runner}-8.out" | awk '{print $4}')
    rps_64=$(grep "Requests per second" "tmp/${runner}-64.out" | awk '{print $4}')
    
    printf "| %-14s | %-10s | %-13s | %-13s | %-14s |\n" \
        "$impl" "$mode" "${rps_1:-N/A}" "${rps_8:-N/A}" "${rps_64:-N/A}"
done | sort -t'|' -k6 -n -r
echo "================================================================================"

