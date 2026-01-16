#!/bin/bash

# Script to extract Starlink-related ASN entries from git history
# Usage: ./extract_starlink_history.sh
# RUN FROM INSIDE as-metadata

if [ "$#" -ne 0 ]; then
	echo "Usage: $0"
	echo "Error: No argument required, got $#"
	exit 1
fi

OUTPUT_FILE="../data/starlink_ASNs/$(date +%Y%m%d_%H%M%S).csv"
TEMP_FILE="temp_as.csv"
SEEN_ASNS="seen_asns.txt"

> "$OUTPUT_FILE"
> "$SEEN_ASNS"

echo "Searching for commits with 'Update YYYYMMDD-HHMM' pattern..."

commits=$(git log --all --oneline --grep="^Update [0-9]\{8\}-[0-9]\{4\}$" --pretty=format:"%H %s" | tac)

if [ -z "$commits" ]; then
    echo "No commits found matching the pattern"
    rm -f "$TEMP_FILE" "$SEEN_ASNS"
    exit 1
fi

echo "Found $(echo "$commits" | wc -l) matching commits"
echo ""

while IFS= read -r line; do
    commit_hash=$(echo "$line" | awk '{print $1}')
    commit_msg=$(echo "$line" | cut -d' ' -f2-)
    
    echo "Processing commit: $commit_hash - $commit_msg"
    
    if ! git cat-file -e "$commit_hash:as.csv" 2>/dev/null; then
        echo "  as.csv not found in this commit, skipping..."
        continue
    fi
    
    git show "$commit_hash:as.csv" > "$TEMP_FILE"
    
    {
        grep -i starlink "$TEMP_FILE" 2>/dev/null
        grep -i "space ex" "$TEMP_FILE" 2>/dev/null
        grep -i spacex "$TEMP_FILE" 2>/dev/null
    } | sort -u | while IFS= read -r result_line; do
        asn=$(echo "$result_line" | cut -d',' -f1)
        
        if ! grep -q "^${asn}$" "$SEEN_ASNS" 2>/dev/null; then
            echo "$result_line" >> "$OUTPUT_FILE"
            echo "$asn" >> "$SEEN_ASNS"
            echo "  Added: $asn"
        fi
    done
    
    echo ""
done <<< "$commits"

rm -f "$TEMP_FILE" "$SEEN_ASNS"

echo "Done! Results saved to $OUTPUT_FILE"
echo "Total unique ASNs found: $(wc -l < "$OUTPUT_FILE")"
