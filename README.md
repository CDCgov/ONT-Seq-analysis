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
10. Generate variant table using ([`IVAR Variants`](https://andersen-lab.github.io/ivar/html/index.html)).
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


First, prepare a samplesheet with your input data that looks as follows*:

`samplesheet.csv`:

```csv
sample,fastq_1,fastq_2
CONTROL_REP1,AEG588A1_S1_L002_R1_001.fastq.gz,
```
A script is provided to convert a directory of fastq files into the required input sheet. Script can be found on `/assets/ont_fastq_concat_and_samplesheet_create.sh`

*Using single end (SE) data for building this workflow

Now, you can run the pipeline using:

<!-- TODO nf-core: update the following command to include all required parameters for a minimal example -->

```bash
nextflow run ONT/mpoxseqanalysis \
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
> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_;
> see [docs](https://nf-co.re/usage/configuration#custom-configuration-files).

## Credits

ONT/mpoxseqanalysis was originally written by Luis Antonio Haddock.

We thank the following people for their extensive assistance in the development of this pipeline:

1. Crystal Gigante, PhD
2. Daisy McGrath
3. ...

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
