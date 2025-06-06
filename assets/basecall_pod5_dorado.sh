#!/bin/bash -l
#$ -o dorado_basecall.out
#$ -e dorado_basecall.err
#$ -N DoradoBasecall
#$ -cwd
#$ -q gpu.q
#$ -l GPU=1

source /etc/profile

# --- Load Modules ---
# Load specific module versions as needed for your system.
echo "Loading dorado/LATEST and miniconda/24.11.1 modules..."
module load dorado/0.9.1 || { echo "ERROR: Failed to load dorado/0.9.1 module. Exiting."; exit 1; }
module load miniconda/24.11.1 || { echo "ERROR: Failed to load miniconda/24.11.1 module. Exiting."; exit 1; }

# --- Configuration Variables ---
# IMPORTANT: Adjust these paths and names according to your setup.

# Directory containing your input raw fast5 files. This should be the top-level
# directory that contains your barcode subdirectories (e.g., barcode03, barcode05).
INPUT_FAST5_DIR="/path/to/fast5_pass/" #YOU MUST CHANGE THIS!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# --- Output Directories and Files ---
# Define a base output directory for all generated files relative to the current working directory.
OUTPUT_BASE_DIR="/path/to/output/directory" #YOU MUST CHANGE THIS!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# Directory where temporary POD5 files (per barcode) will be stored during conversion.
TEMP_POD5_DIR="${OUTPUT_BASE_DIR}/temp_pod5_data"

# Full path and filename for the final, merged POD5 file. This will be the input for dorado basecalling.
MERGED_POD5_FILE="${OUTPUT_BASE_DIR}/merged_reads.pod5"

# Base directory for Dorado's basecalled and demultiplexed outputs.
DORADO_RUN_OUTPUT_BASE_DIR="${OUTPUT_BASE_DIR}/dorado_output"

# Directory where Dorado's basecalled output will be written.
BASECALL_OUTPUT_DIR="${DORADO_RUN_OUTPUT_BASE_DIR}/basecalled"

# Directory where Dorado's demultiplexed output will be written.
DEMUX_OUTPUT_DIR="${DORADO_RUN_OUTPUT_BASE_DIR}/demuxed"


# The name of the Dorado basecalling model to use.
# Using just the name (e.g., 'sup', 'hac', 'fast') allows Dorado to automatically select
# the appropriate model version for your data's sample rate and chemistry (e.g., 5000 Hz for R10.4.1).
# Run 'dorado download --list-models' to see all available model names.
DORADO_MODEL_NAME="sup"

# The name of your Conda environment where POD5 tools are installed.
# Dorado is loaded as a module, so this environment only needs POD5.
CONDA_ENV_NAME="VW_conda"

# Kit name used for barcoding. Match this to your sequencing experiment.
BARCODE_KIT_NAME="EXP-PBC096"

# Minimum Q-score for basecalling.
MIN_QSCORE=10


# --- Script Execution Start ---
echo "=========================================="
echo "Starting Dorado Basecalling and Demultiplexing Workflow"
echo "Current Time: $(date)"
echo "------------------------------------------"
echo "Configuration:"
echo "  Input Fast5 Directory: $INPUT_FAST5_DIR"
echo "  Base Output Directory: $OUTPUT_BASE_DIR"
echo "  Temporary POD5 Directory: $TEMP_POD5_DIR"
echo "  Merged POD5 File: $MERGED_POD5_FILE"
echo "  Dorado Run Output Base Dir: $DORADO_RUN_OUTPUT_BASE_DIR"
echo "  Basecall Output Dir: $BASECALL_OUTPUT_DIR"
echo "  Demux Output Dir: $DEMUX_OUTPUT_DIR"
echo "  Dorado Model Name: $DORADO_MODEL_NAME"
echo "  Conda Environment (for POD5): $CONDA_ENV_NAME"
echo "  Barcode Kit Name: $BARCODE_KIT_NAME"
echo "  Minimum Q-score: $MIN_QSCORE"
echo "=========================================="

# Create all necessary output directories if they do not already exist.
mkdir -p "$TEMP_POD5_DIR" || { echo "ERROR: Failed to create $TEMP_POD5_DIR. Exiting."; exit 1; }
mkdir -p "$(dirname "$MERGED_POD5_FILE")" || { echo "ERROR: Failed to create directory for $MERGED_POD5_FILE. Exiting."; exit 1; }
mkdir -p "$BASECALL_OUTPUT_DIR" || { echo "ERROR: Failed to create $BASECALL_OUTPUT_DIR. Exiting."; exit 1; }
mkdir -p "$DEMUX_OUTPUT_DIR" || { echo "ERROR: Failed to create $DEMUX_OUTPUT_DIR. Exiting."; exit 1; }


# Remove previously created merged POD5 file if it exists, to prevent errors on re-runs
if [ -f "$MERGED_POD5_FILE" ]; then
    echo "Removing existing merged POD5 file: $MERGED_POD5_FILE"
    rm "$MERGED_POD5_FILE" || { echo "WARNING: Failed to remove existing merged POD5 file. Continuing anyway. This might cause issues."; }
fi

# Clean up previous basecalled/demuxed output directories if they exist, to ensure fresh run
if [ -d "$DORADO_RUN_OUTPUT_BASE_DIR" ]; then
    echo "Removing existing Dorado run output directory: $DORADO_RUN_OUTPUT_BASE_DIR"
    rm -rf "$DORADO_RUN_OUTPUT_BASE_DIR" || { echo "WARNING: Failed to remove existing Dorado output directory. Continuing anyway."; }
    mkdir -p "$BASECALL_OUTPUT_DIR" # Recreate basecall dir
    mkdir -p "$DEMUX_OUTPUT_DIR" # Recreate demux dir
fi


# --- Activate Conda Environment ---
echo "Activating conda environment: $CONDA_ENV_NAME..."
conda activate "$CONDA_ENV_NAME" || { echo "ERROR: Failed to activate conda environment '$CONDA_ENV_NAME'. Make sure it exists and contains pod5. Exiting."; exit 1; }

# --- Step 1: Convert Fast5 files from each barcode directory to temporary POD5 files ---
echo "------------------------------------------"
echo "Step 1: Converting Fast5 files from subdirectories of '$INPUT_FAST5_DIR' to temporary POD5 files in '$TEMP_POD5_DIR'..."

POD5_FILES_TO_MERGE=() # Initialize an empty array to collect temporary POD5 file paths

# Collect all barcode* and unclassified directories into an array first
# This prevents issues with subshells when modifying the POD5_FILES_TO_MERGE array.
readarray -t BARCODE_DIRS < <(find "$INPUT_FAST5_DIR" -maxdepth 1 -type d \( -name "barcode*" -o -name "unclassified" \) | sort)

if [ ${#BARCODE_DIRS[@]} -eq 0 ]; then
    echo "ERROR: No barcode or unclassified subdirectories found in '$INPUT_FAST5_DIR'. Exiting."
    conda deactivate
    module unload miniconda/24.11.1
    module unload dorado/LATEST # Unload latest dorado
    exit 1
fi

for sub_dir in "${BARCODE_DIRS[@]}"; do
    if [ -d "$sub_dir" ]; then # Double-check if it's a directory
        DIR_NAME=$(basename "$sub_dir")
        TEMP_POD5_FILE="$TEMP_POD5_DIR/${DIR_NAME}.pod5"

        echo "Converting fast5 files in directory: '$sub_dir' to '$TEMP_POD5_FILE'..."
        CONVERSION_LOG="$TEMP_POD5_DIR/${DIR_NAME}_pod5_conversion.log"

        # Pre-check if there are any fast5 files in the current subdirectory
        if ! find "$sub_dir" -type f -name "*.fast5" -print -quit | grep -q .; then
            echo "WARNING: No .fast5 files found in '$sub_dir'. Skipping this directory." | tee -a "$CONVERSION_LOG"
            continue # Skip to the next directory
        fi

        # Run pod5 convert with POD5_DEBUG=1 for detailed output and redirect stderr to a log file
        ( export POD5_DEBUG=1; pod5 convert fast5 "$sub_dir" --output "$TEMP_POD5_FILE" ) 2> "$CONVERSION_LOG" || {
            echo "ERROR: Fast5 to POD5 conversion failed for directory '$sub_dir'." | tee -a "$CONVERSION_LOG"
            echo "Check permissions, file integrity, and the contents of $CONVERSION_LOG for more details."
            echo "Attempting to continue with other directories..."
            continue # Attempt to continue with other directories if conversion fails
        }
        echo "Conversion of '$sub_dir' complete." | tee -a "$CONVERSION_LOG"
        POD5_FILES_TO_MERGE+=("$TEMP_POD5_FILE") # Add to the array for merging
    fi
done

if [ ${#POD5_FILES_TO_MERGE[@]} -eq 0 ]; then
    echo "ERROR: After attempting conversions, no temporary POD5 files were successfully generated. Exiting."
    conda deactivate
    module unload miniconda/24.11.1
    module unload dorado/LATEST
    exit 1
fi
echo "All barcode directories processed. Collected ${#POD5_FILES_TO_MERGE[@]} temporary POD5 files for merging."


# --- Step 2: Merge all temporary POD5 files into one master POD5 file ---
echo "------------------------------------------"
echo "Step 2: Merging all temporary POD5 files into '$MERGED_POD5_FILE'..."
# Use array expansion "${POD5_FILES_TO_MERGE[@]}" to pass each file as a separate argument
pod5 merge "${POD5_FILES_TO_MERGE[@]}" --output "$MERGED_POD5_FILE" || {
    echo "ERROR: Merging temporary POD5 files failed. Exiting.";
    conda deactivate
    module unload miniconda/24.11.1
    module unload dorado/LATEST
    exit 1;
}
echo "POD5 merge complete. Master POD5 file: $MERGED_POD5_FILE"


# --- Step 3: Basecall the merged POD5 file using Dorado ---
echo "------------------------------------------"
echo "Step 3: Basecalling merged POD5 file ('$MERGED_POD5_FILE') using Dorado model '$DORADO_MODEL_NAME'..."
# Dorado basecaller arguments:
# --min-qscore 10: filters reads below a Q-score of 10
# --kit-name EXP-PBC096: specifies the sequencing kit
# --barcode-both-ends: uses both ends of the read for barcode detection
# --no-trim: prevents trimming of adapters
# --emit-fastq: ensures FASTQ output is generated
# -o $BASECALL_OUTPUT_DIR: directs basecalled FASTQ files to this directory
dorado basecaller "$DORADO_MODEL_NAME" "$MERGED_POD5_FILE" \
    --min-qscore "$MIN_QSCORE" \
    --kit-name "$BARCODE_KIT_NAME" \
    --barcode-both-ends \
    --no-trim \
    --emit-fastq \
    -o "$BASECALL_OUTPUT_DIR" || {
    echo "ERROR: Dorado basecalling failed. Check model name, input POD5 file, and Dorado logs in '$BASECALL_OUTPUT_DIR'."
    conda deactivate
    module unload miniconda/24.11.1
    module unload dorado/LATEST
    exit 1;
}
echo "Dorado basecalling complete. Output in: $BASECALL_OUTPUT_DIR"


# --- Step 4: Demultiplex the basecalled reads using Dorado ---
echo "------------------------------------------"
echo "Step 4: Demultiplexing basecalled reads from '$BASECALL_OUTPUT_DIR' to '$DEMUX_OUTPUT_DIR'..."
# Dorado demux arguments:
# --kit-name EXP-PBC096: specifies the sequencing kit for demultiplexing
# --emit-summary: generates a demultiplexing summary report
# --emit-fastq: ensures FASTQ output is generated per barcode
# --output-dir $DEMUX_OUTPUT_DIR: directs demultiplexed files to this directory
dorado demux \
    --kit-name "$BARCODE_KIT_NAME" \
    --emit-summary \
    --emit-fastq \
    --output-dir "$DEMUX_OUTPUT_DIR" \
    "$BASECALL_OUTPUT_DIR" || {
    echo "ERROR: Dorado demultiplexing failed. Check input basecalled directory and Dorado logs in '$DEMUX_OUTPUT_DIR'."
    conda deactivate
    module unload miniconda/24.11.1
    module unload dorado/LATEST
    exit 1;
}
echo "Dorado demultiplexing complete. Output in: $DEMUX_OUTPUT_DIR"


# --- Step 5: Generate pseudo-paired-end FASTQ files per barcode ---
echo "------------------------------------------"
echo "Step 5: Generating pseudo-paired-end FASTQ files for each barcode..."
for barcode_dir in "$DEMUX_OUTPUT_DIR"/barcode*; do
    if [[ -d "$barcode_dir" ]]; then
        barcode=$(basename "$barcode_dir")
        # Define output paired-end FASTQ filenames
        fastq1="${barcode_dir}/${barcode}_R1.fastq"
        fastq2="${barcode_dir}/${barcode}_R2.fastq"

        echo "Processing barcode: $barcode (output to $fastq1 and $fastq2)"

        # Check if there are FASTQ files to process in the barcode directory
        if ! find "$barcode_dir" -maxdepth 1 -type f -name "*.fastq" -print -quit | grep -q .; then
            echo "WARNING: No .fastq files found in '$barcode_dir' for paired-end processing. Skipping."
            continue
        fi

        # Use awk to split the combined FASTQ into pseudo-paired-end files.
        # This assumes a specific pattern for splitting reads.
        # Note: Nanopore reads are typically single-end. This step creates synthetic R1/R2.
        cat "$barcode_dir"/*.fastq | awk '
            BEGIN {
                read_number = 1; # Start with R1
                output_file1 = ENVIRON["FASTQ1_OUT"];
                output_file2 = ENVIRON["FASTQ2_OUT"];
            }
            {
                print >> (read_number == 1 ? output_file1 : output_file2);
                if (NR % 4 == 0) { # After every 4 lines (a full FASTQ record)
                    read_number = (read_number == 1 ? 2 : 1); # Toggle read number for next record
                }
            }
            ' FASTQ1_OUT="$fastq1" FASTQ2_OUT="$fastq2" || {
            echo "ERROR: Failed to generate paired-end files for '$barcode'."
            # Continue to next barcode if this one fails
            continue
        }
        echo "Paired-end files created for $barcode."
    fi
done
echo "Pseudo-paired-end FASTQ generation complete for all barcodes."


# --- Deactivate Conda Environment ---
echo "------------------------------------------"
echo "Deactivating conda environment..."
conda deactivate || { echo "WARNING: Failed to deactivate conda environment."; }

# --- Unload Modules ---
echo "Unloading modules..."
module unload miniconda/24.11.1 || { echo "WARNING: Failed to unload miniconda/24.11.1 module."; }
module unload dorado/LATEST || { echo "WARNING: Failed to unload dorado/LATEST module."; }

echo "------------------------------------------"
echo "Dorado Basecalling and Demultiplexing Workflow finished successfully!"
echo "Current Time: $(date)"
echo "=========================================="
