#!/bin/bash

# Script to extract Starlink-related ASN entries from git history
# Usage: ./extract_starlink_history.sh <output_file_path>

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <output_file_path>"
	echo "Error: One argument required, got $#"
	exit 1
fi

OUTPUT_FILE="$1$(date +%Y%m%d_%H%M%S)_starlink_ASNs.csv"
TEMP_FILE="$1temp_as.csv"
SEEN_ASNS="$1seen_asns.txt"

> "$OUTPUT_FILE"
> "$SEEN_ASNS"

echo "Searching for commits with 'Update YYYYMMDD-HHMM' pattern..."

commits=$(git log --all --oneline --grep="^Update [0-9]\{8\}-[0-9]\{4\}$" --pretty=format:"%H %s" | tail -r)

if [ -z "$commits" ]; then
    echo "No commits found matching the pattern"
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
