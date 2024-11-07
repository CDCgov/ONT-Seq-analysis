#!/bin/bash

echo "Ensure you are in the working directory where you want to save the samplesheet."

# Prompt the user for the path to the output directory
read -p "Please enter the path to the data output directory with contatenated fastq files (ending the path with a ("/") symbol)  : " output_dir

# Step 1: Create samplesheet.csv
samplesheet="samplesheet.csv"
printf "sample,fastq_1,fastq_2\n" > "$samplesheet"

# Loop through the output directory to create the samplesheet
current_dir=$(pwd)
for subdir in "$output_dir"*; do
    if [[ -d "$subdir" ]]; then
        subdir_name=$(basename "$subdir")
        subdir_name_cl=$(basename "$subdir" | sed 's/-/_/g')
        merged_file="$subdir/${subdir_name}_merged.fastq.gz"

        # Append the subdirectory name and the path to the merged file to the CSV file
        if [[ -f "$merged_file" ]]; then
            printf "%s,%s,\n" "$subdir_name_cl" "$merged_file" >> "$samplesheet"
        else
            echo "Merged file not found for $subdir_name: $merged_file"
        fi
    fi
done

# Replace hyphens and parenthesis with underscores in only the first column (subdir_name)
sed -i 's/^\([^,]*\)[-()]/\1_/g; t; s/^\([^,]*\)[-()]/\1_/g' "$samplesheet"

echo "Samplesheet created: $samplesheet at $(date '+%Y-%m-%d %H:%M:%S') in $current_dir"
