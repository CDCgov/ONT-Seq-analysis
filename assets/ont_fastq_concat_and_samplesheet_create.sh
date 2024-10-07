#!/bin/bash

echo "Ensure you currently are in the wd you will save the merged files to. A directory will be created automatically to store all merged files."
# Prompt the user for the path to the data directory
read -p "Please enter the path to the data directory: " data_dir

# Step 1: Create a 'data_output' folder in the current working directory
output_dir="data_output"
mkdir -p "$output_dir"
current_dir=$(pwd)

# Step 2: Loop through the 'data' directory to merge FASTQ files
for subdir in "$data_dir"/*; do
    if [[ -d "$subdir" ]]; then
        subdir_name=$(basename "$subdir")

        # Creating a subdirectory inside 'data_output' for each subdirectory
        mkdir -p "$output_dir/$subdir_name"
        
        # Prepare an output file name
        output_file="$output_dir/$subdir_name/${subdir_name}_merged.fastq.gz"

        # If there are fastq files, concatenate them and compress
        if ls "$subdir"/*.fastq 1> /dev/null 2>&1; then
            cat "$subdir"/*.fastq | gzip > "$output_file"
        fi

        # If there are gzipped fastq files, concatenate them after decompressing and compress
        if ls "$subdir"/*.fastq.gz 1> /dev/null 2>&1; then
            zcat "$subdir"/*.fastq.gz | gzip >> "$output_file"
        fi

        echo "Concatenated files from $subdir_name and saved as $output_file at $(date '+%Y-%m-%d %H:%M:%S')"
    fi
done


# Step 3: Create samplesheet.csv
samplesheet="samplesheet.csv"
#echo "sample,fastq_1,fastq_2" > "$samplesheet"
printf "sample,fastq_1,fastq_2\n" > "$samplesheet"

#parent_path="$current_dir" #/${output_dir%/*}"

# Loop through the output directory to create the samplesheet
for subdir in "$output_dir"/*; do
    if [[ -d "$subdir" ]]; then
        subdir_name=$(basename "$subdir")
        subdir_name_cl=$(basename "$subdir" | sed 's/-/_/g')
        merged_file="$current_dir/$subdir/${subdir_name}_merged.fastq.gz"

        # Append the subdirectory name and the path to the merged file to the TSV file
        if [[ -f "$merged_file" ]]; then
            printf "%s,%s,\n" "$subdir_name_cl" "$merged_file" >> "$samplesheet"
        else
            echo "Merged file not found for $subdir_name: $merged_file"
        fi
    fi
done

# Replace hyphens with underscores in only the first column (subdir_name)
sed -i 's/^\([^,]*\)-/\1_/g; t; s/^\([^,]*\)-/\1_/g' "$samplesheet"

echo "Samplesheet created: $samplesheet at $(date '+%Y-%m-%d %H:%M:%S')"