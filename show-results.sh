#!/bin/sh

TMP_DIR="tmp"

[ -d "$TMP_DIR" ] || { echo "no results files - run benchmark tests first"; exit 1; }

# ==============================================================================
# STAGE 3: REPORT GENERATION
# ==============================================================================
echo
echo "================================================================================"
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
done | sort -t'|' -k6 -n -r | perl -p -e s#'0.00'#'N/A '#g


echo "================================================================================"

