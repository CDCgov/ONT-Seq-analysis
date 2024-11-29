## Introduction

**ONT/mpoxseqanalysis** is a pipeline that inputs ONT sequencing data of Mpox isolates and performs a reference-based assembly followed by a variant table analysis relative to the reference used. It takes a samplesheet and FASTQ files as input, performs quality control (QC), trimming, alignment, nextclade run to identify viral genetic variants, and produces an extensive QC report.

<!-- TODO nf-core: Include a figure that guides the user through the major workflow steps. Many nf-core
     workflows use the "tube map" design for that. See https://nf-co.re/docs/contributing/design_guidelines#examples for examples.   -->
<!-- TODO nf-core: Fill in short bullet-pointed list of the default steps in the pipeline -->

Main steps of the workflow:

1. Read QC ([`FastQC`](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/)).
2. Sequencing Toolkit ([`SEQTK`](https://github.com/lh3/seqtk)) Trim to remove primers.
3. Trimming of raw reads to specific length using ([`Trimmomatic`](https://github.com/usadellab/Trimmomatic)).
4. Maps raw reads to reference and generate a refined consensus using ([`Minimap2`](https://github.com/lh3/minimap2)) and ([`IVAR Consensus`](https://andersen-lab.github.io/ivar/html/index.html)).
5. ([`Samtools`](https://www.htslib.org/)) to manage alignment files and obtain depth of coverage.
9. Polish consensus using ([`MEDAKA`](https://github.com/nanoporetech/medaka)).
10. Generate a variant table using ([`IVAR Variants`](https://andersen-lab.github.io/ivar/html/index.html)).
11. ([`Nextclade`](https://docs.nextstrain.org/projects/nextclade/en/stable/index.html)) for clade assignment, mutation calling, phylogenetic placement, and quality checks for Mpox (Monkeypox).
12. Present QC for raw reads ([`MultiQC`](http://multiqc.info/)).

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.

<!-- TODO nf-core: Describe the minimum required steps to execute the pipeline, e.g. how to prepare samplesheets.
     Explain what rows and columns represent. For instance (please edit as appropriate):

First, prepare a samplesheet with your input data that looks as follows:

`samplesheet.csv`:

```csv
sample,fastq_1,fastq_2
CONTROL_REP1,AEG588A1_S1_L002_R1_001.fastq.gz,AEG588A1_S1_L002_R2_001.fastq.gz
```

Each row represents a fastq file (single-end) or a pair of fastq files (paired end).

-->

First, prepare a samplesheet with your input data containing single-end ONT fastq files:

`samplesheet.csv`:

```csv
sample,fastq_1,fastq_2
SAMPLE_NAME_1,RANDOM_NAME_S1_L002_R1_001.fastq.gz,
```
A script is available to concatenate barcoded FASTQ files in a directory and generate a samplesheet in the required input format. You can find this script in `/assets/ont_fastq_concat_and_samplesheet_create.sh`. Ensure you’re in the working directory where you’d like the files merged and saved, as the script will automatically create a directory to store the resulting files, placing the samplesheet file in the same directory. Make sure to enter the path to the directory with the FASTQ files, ending with a "/" symbol.

If your FASTQ files are already concatenated by barcode, you can generate only the samplesheet by running `/assets/create_samplesheet_only.sh`. Enter the path to the directory with concatenated FASTQ files, ending with a "/", and ensure you are in the working directory where you want to save the samplesheet.

>[!WARNING]
Avoid using special characters (parentheses, commas, asterisks, hashes, etc.) in FASTQ file names. Only use letters, numbers, underscores (_), and hyphens (-) for better compatibility with the workflow and to avoid unexpected crashes of the runs.

Repository needs to be cloned using `git clone`
```
git clone https://github.com/CDCgov/ONT-Seq-analysis
```
Now, you can run the pipeline using:

<!-- TODO nf-core: update the following command to include all required parameters for a minimal example -->

```bash
nextflow run mpox_ont_seq_analysis \
   -profile <docker/singularity/.../institute> \
   --input samplesheet.csv \
   --outdir <OUTDIR> \
   -resume <#if applicable> \
   --fasta <fasta_path> \
   --bed_file <bed_path> \
   --fai_file <fai_path> \
   --gff_file <gff_path> \
   --mmi_file <mmi_path> \
   --nextclade_dataset_name 'nextstrain/mpox/all-clades'
```
_*Reference files for Mpox [NC063383] have been provided in `/assets/NC063383_mpox/`_


Nextclade output files can be modified to remove unnecesary columns. To do so, run the filtering script (`assets/nextclade_tsv_column_filter.sh`) inside the `Nextclade` output directory. The resulting TSV file will contain the following colums: `'index', 'seqName', 'clade', 'lineage', 'outbreak', 'qc.overallScore', 'qc.overallStatus', 'totalSubstitutions', 'totalDeletions', 'totalInsertions', 'totalFrameShifts', 'totalMissing', 'totalNonACGTNs', 'failedCdses', 'warnings', 'errors'`. Feel free to modify as needed.

> [!WARNING]
Note that, for historical reasons, the developers use semicolon (;) as the column separator in CSV files because they have comma (,) as list separators within table cells. In early versions of Nextclade, their CSV writer code was imperfect, making this an easy solution. They recommend using TSV format instead of CSV format. However, if using CSV format, it is important to configure spreadsheet software or parsers to use semicolons (;) as column delimiters.

We have also included a python script to extract mutations from each nextclade output file and for each specimen, returning a table highlighting key mutations that could indicate a designation of Clade I or Clade II, including the different lineages. Run the python script (`assets/pythonX_nextclade_parser.py`) inside the `Nextclade` output directory. It will generate a directory named `parser` that will contain a tsv file for each specimen with the following format:

| seq_name | Mutations_found_on_sequence | Found_in_Clade_I_or_Clade_II | Clade_designation |
|----------|-----------------------------|------------------------------|--------------------|
| sample1  | G01234A                    | yes                          | Clade Ia          |
| sample1  | G56789A                    | yes                          | Clade IIb         |



For more information visit the [Nextclade CLI](https://docs.nextstrain.org/projects/nextclade/en/stable/index.html) homepage.

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_:
> see [docs](https://nf-co.re/usage/configuration#custom-configuration-files).

## Credits

ONT/mpoxseqanalysis was originally written by Luis Antonio Haddock, PhD (CDC).

We thank the following people for their extensive assistance in the development of this pipeline:

1. Crystal Gigante, PhD (CDC)
2. Daisy McGrath (CDC)
3. Christopher Gulvik, PhD (CDC)

<!-- TODO nf-core: If applicable, make list of people who have also contributed -->

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use ONT/mpoxseqanalysis for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/master/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
