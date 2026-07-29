#!/bin/sh

INI="params.ini"

# Source params.ini to load variables ($TMP_DIR, $LOW_C, $MID_C, $HIGH_C)
if [ -r "$INI" ]; then
    . "./$INI"
else
    # Fallback to local default if file is missing
    TMP_DIR="tmp"
    LOW_C=1
    MID_C=8
    HIGH_C=64
fi

if [ ! -d "$TMP_DIR" ]; then
    echo "no results files - run benchmark tests first"
    exit 1
fi

# ==============================================================================
# STAGE 3: REPORT GENERATION
# ==============================================================================
echo
echo "================================================================================"
echo "|  BENCHMARK SUMMARY (Requests per second, sorted by max concurrency result)   |"
echo "================================================================================"

# Dynamic Table Header using parameter values
printf "| %-14s | %-10s | %3d Client(s) | %3d Client(s) | %3d Client(s)  |\n" \
    "Language" "Mode" "$LOW_C"  "$MID_C"  "$HIGH_C" 
echo "|----------------|------------|---------------|---------------|----------------|"

# Target the wildcards dynamically using the LOW_C variable
for out_file in "$TMP_DIR"/*-"$LOW_C".out; do
    [ -e "$out_file" ] || continue
    
    # Strip paths and construct exact filenames dynamically
    runner="${out_file#"$TMP_DIR"/}"
    runner="${runner%-"$LOW_C".out}"
    impl="${runner%_*}"
    mode="${runner##*_}"
    
    # Read out individual metrics safely
    rps_low=$(cat "$TMP_DIR/${runner}-${LOW_C}.out" 2>/dev/null)
    rps_mid=$(cat "$TMP_DIR/${runner}-${MID_C}.out" 2>/dev/null)
    rps_high=$(cat "$TMP_DIR/${runner}-${HIGH_C}.out" 2>/dev/null)
    
    # Print raw data for awk processing
    printf "%s\t%s\t%s\t%s\t%s\n" "$impl" "$mode" "${rps_low:-0}" "${rps_mid:-0}" "${rps_high:-0}"
done | awk -F'\t' '
{
    lang = $1
    # Check if this mode has a higher high-concurrency score
    if ($5 + 0 > max_high[lang] + 0 || !max_high[lang]) {
        max_high[lang] = $5
        mode[lang] = $2
        r_low[lang] = $3
        r_mid[lang] = $4
    }
}
END {
    for (lang in max_high) {
        printf "| %-14s | %-10s | %13.2f | %13.2f | %14.2f |\n", \
            lang, mode[lang], r_low[lang], r_mid[lang], max_high[lang]
    }
}' | sort -t'|' -k6 -n -r | awk '{gsub(/ 0.00 /, " N/A "); print}'

echo "================================================================================"

