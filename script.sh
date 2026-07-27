#!/bin/sh

cd tmp

echo "ENGINE     | MODE       | C-1       | C-8       | C-64" && echo "--------------------------------------------------------" && for f in tmp/*.out; do [ -e "$f" ] || continue; base=$(basename "$f" .out); eng=$(echo "$base" | cut -d'_' -f1); rem=$(echo "$base" | cut -d'_' -f2); mode=$(echo "$rem" | cut -d'-' -f1); c=$(echo "$rem" | cut -d'-' -f2); val=$(cat "$f"); echo "$eng|$mode|$c|$val"; done | awk -F'|' '{metrics[$1"|"$2][$3] = $4} END {for (key in metrics) {split(key, parts, "|"); printf "%-10s | %-10s | %-9s | %-9s | %-9s\n", parts[1], parts[2], metrics[key]["1"] ? metrics[key]["1"] : "0.00", metrics[key]["8"] ? metrics[key]["8"] : "0.00", metrics[key]["64"] ? metrics[key]["64"] : "0.00"}}' | sort
