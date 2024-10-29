#!/bin/bash

# Define the directory containing the TSV files
input_dir="run"
output_dir="cleaned"

# Create the output directory if it doesn't exist
mkdir -p "$output_dir"

# Define the columns to keep
columns_to_keep=("index" "seqName" "clade" "lineage" "outbreak" "qc.overallScore" 
                  "qc.overallStatus" "totalSubstitutions" "totalDeletions" 
                  "totalInsertions" "totalFrameShifts" "totalMissing" 
                  "totalNonACGTNs" "failedCdses" "warnings" "errors")

# Create a regex pattern from the column names
regex_pattern=$(IFS=\|; echo "${columns_to_keep[*]}")

# Iterate over each TSV file in the input directory
for file in "$input_dir"/*.tsv; do
    # Get the base filename without extension
    base_name=$(basename "$file" .tsv)

    # Use awk to extract the desired columns and save to a new file
    awk -F'\t' -v OFS='\t' -v pattern="$regex_pattern" '
    NR==1 {
        # Store header and identify indices of columns to keep
        for (i=1; i<=NF; i++) {
            if ($i ~ pattern) {
                indices[++count] = i
                header[i] = $i
            }
        }
        # Print the header for kept columns
        for (i=1; i<=count; i++) {
            printf "%s%s", header[indices[i]], (i==count ? "\n" : OFS)
        }
        next
    }
    {
        # Print the data for the kept columns
        for (i=1; i<=count; i++) {
            printf "%s%s", $(indices[i]), (i==count ? "\n" : OFS)
        }
    }
    ' "$file" > "$output_dir/${base_name}_clean.tsv"
done
