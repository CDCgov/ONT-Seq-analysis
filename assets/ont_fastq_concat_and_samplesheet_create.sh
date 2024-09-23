#!/bin/bash


Author: Luis A Haddock


# Ask for the path to the data directory
read -p "Please enter the path to the data directory: " data_dir

# Step 1: Create a 'data_output' folder in the current working directory
output_dir="data_output"
mkdir -p "$output_dir"

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

        echo "Concatenated files in $subdir_name and saved as $output_file"
    fi
done


# Step 3: Create samplesheet.tsv
samplesheet="samplesheet.tsv"
echo -e "sample\tfastq_1" > "$samplesheet"

# Extracting the base path to use later
parent_path="${data_dir%/*}"

# Loop through the output directory to create the samplesheet
for subdir in "$output_dir"/*; do
    if [[ -d "$subdir" ]]; then
        subdir_name=$(basename "$subdir")
        merged_file="$parent_path/$subdir/${subdir_name}_merged.fastq.gz"

        # Append the subdirectory name and the path to the merged file to the TSV file
        if [[ -f "$merged_file" ]]; then
            echo -e "$subdir_name\t$merged_file" >> "$samplesheet"
        else
            echo "Merged file not found for $subdir_name: $merged_file"
        fi
    fi
done

echo "Samplesheet created: $samplesheet"
