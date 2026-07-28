#!/bin/sh

OS=`uname -s`

# 1. Verify apachebench installation safely
AB_BIN=$(command -v ab)
if [ $? -ne 0 ]; then
    echo "ERROR: apachebench (ab) must be installed to run benchmarks."
    exit 1
fi

N=8192
RUNS_PER_TEST=5 # Number of times to repeat each specific test variation
TMP_DIR="tmp"

[ -d "$TMP_DIR" ] || mkdir "$TMP_DIR"
rm -f "$TMP_DIR"/*

cleanup_port() {
    pid=""
    if [ $OS = "Linux" ] || [ $OS = "FreeBSD" ]; then
      if command -v sockstat >/dev/null 2>&1; then
          pid=$(sockstat -46l -P tcp -p 8080 | awk 'NR>1 {print $3}' | sort -u)
      elif command -v lsof >/dev/null 2>&1; then
          pid=$(lsof -t -i :8080)
      elif command -v fuser >/dev/null 2>&1; then
          pid=$(fuser 8080/tcp 2>/dev/null)
      fi
    elif [ $OS = "OpenBSD" ]; then
       pid=$(fstat | grep :8080 | awk '{print $3}') 
    fi

    if [ -n "$pid" ]; then
        kill -9 $pid >/dev/null 2>&1
        sleep 1.5
    fi
}

echo
echo "================================================================================"
echo " STAGE 2: RUNNING BENCHMARKS (WITH AVERAGING)"
echo "================================================================================"

for i in run-httpd.*; do
    [ -e "$i" ] || continue
    base="${i#run-httpd.}"
    cleanup_port

    case "$base" in
        bun)          REQ_CMD="bun" ;;
	c)	      REQ_CMD="cc" ;;
	crystal)      REQ_CMD="crystal" ;;
        go)           REQ_CMD="go" ;;
        node|js)      REQ_CMD="node" ;;
	# perl server depends on plack & Starman
        perl|pl)      REQ_CMD="plackup >/dev/null 2>&1 && perl -MStarman -e" ;; 
        powershell|ps1) REQ_CMD="pwsh" ;;
        python|py)    REQ_CMD="python3" ;;
        raku)         REQ_CMD="raku" ;;
        rb|ruby)      REQ_CMD="ruby" ;;
        rust)	      REQ_CMD="rustc" ;;
        zig)	      REQ_CMD="zig" ;;
        *)            REQ_CMD="" ;;
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
        
        # Start server background process tree
        ./"$i" &
        SERVER_PID=$!
        
        # Warmup period for worker pool cluster initialization
        sleep 3

        for c in 1 8 64; do
            echo "  -> Testing Concurrency -$c ($RUNS_PER_TEST iterations)..."
            
            # Create a localized temporary tracking file for raw runs
	    raw_runs_file="$TMP_DIR/${base}_${mode}-${c}.raw"
            rm -f "$raw_runs_file"

            # Execute the test iteration matrix
	    run_idx=1
            while [ "$run_idx" -le "$RUNS_PER_TEST" ]; do
                # 1. Capture the raw text output from ab by removing 2>/dev/null
                ab_raw_output=$(ab $K_FLAG -n $N -c $c http://127.0.0.1:8080/ 2>&1)

                # 2. Extract the metric using awk
                rps=$(echo "$ab_raw_output" | awk -F'[^0-9.]+' '/Requests per second/ {print $2}')

                # Verify we caught a valid numeric metric
                if [ -n "$rps" ]; then
                    echo "$rps" >> "$raw_runs_file"
                else
                    # 3. Print the REAL error message that ab generated
                    echo "DEBUG: Run $run_idx failed. ApacheBench output was:" >&2
                    echo "--------------------------------------------------" >&2
                    echo "$ab_raw_output" | sed 's/^/  /' >&2
                    echo "--------------------------------------------------" >&2
                fi

                sleep 0.3
                run_idx=$((run_idx + 1))
            done


            # Mathematical Aggregator: Drops the high/low outliers if runs >= 3, then averages
	                # Mathematical Aggregator: Robust, cross-platform standard averaging
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
			# Sort array to drop highest and lowest
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
	    }
            ' "$raw_runs_file" > "$TMP_DIR/${base}_${mode}-${c}.out"

             # Cleanup the raw telemetry run files
             rm -f "$raw_runs_file"
	else
	    echo "0.00" > "$TMP_DIR/${base}_${mode}-${c}.out"
	fi
    done

    # Clean kill the server process instance and underlying multi-core workers
    if kill -0 "$SERVER_PID" >/dev/null 2>&1; then
        kill -9 "$SERVER_PID" >/dev/null 2>&1
    fi
    cleanup_port
  done
done

