**General disclaimer** This repository was created for use by CDC programs to collaborate on public health related projects in support of the [CDC mission](https://www.cdc.gov/about/organization/mission.htm).  GitHub is not hosted by the CDC, but is a third party website used by CDC and its partners to share information and collaborate on software. CDC use of GitHub does not imply an endorsement of any one particular service, product, or enterprise. 

## Privacy Standard Notice
This repository contains only non-sensitive, publicly available data and
information. All material and community participation is covered by the
[Disclaimer](DISCLAIMER.md)
and [Code of Conduct](code-of-conduct.md).
For more information about CDC's privacy policy, please visit [http://www.cdc.gov/other/privacy.html](https://www.cdc.gov/other/privacy.html).

Full disclaimer can be found at the end of this markdown file.

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



# CDCgov GitHub Organization Open Source Project Template

**Template for clearance: This project serves as a template to aid projects in starting up and moving through clearance procedures. To start, create a new repository and implement the required [open practices](open_practices.md), train on and agree to adhere to the organization's [rules of behavior](rules_of_behavior.md), and [send a request through the create repo form](https://forms.office.com/Pages/ResponsePage.aspx?id=aQjnnNtg_USr6NJ2cHf8j44WSiOI6uNOvdWse4I-C2NUNk43NzMwODJTRzA4NFpCUk1RRU83RTFNVi4u) using language from this template as a Guide.**

**General disclaimer** This repository was created for use by CDC programs to collaborate on public health related projects in support of the [CDC mission](https://www.cdc.gov/about/organization/mission.htm).  GitHub is not hosted by the CDC, but is a third party website used by CDC and its partners to share information and collaborate on software. CDC use of GitHub does not imply an endorsement of any one particular service, product, or enterprise. 

## Access Request, Repo Creation Request

* [CDC GitHub Open Project Request Form](https://forms.office.com/Pages/ResponsePage.aspx?id=aQjnnNtg_USr6NJ2cHf8j44WSiOI6uNOvdWse4I-C2NUNk43NzMwODJTRzA4NFpCUk1RRU83RTFNVi4u) _[Requires a CDC Office365 login, if you do not have a CDC Office365 please ask a friend who does to submit the request on your behalf. If you're looking for access to the CDCEnt private organization, please use the [GitHub Enterprise Cloud Access Request form](https://forms.office.com/Pages/ResponsePage.aspx?id=aQjnnNtg_USr6NJ2cHf8j44WSiOI6uNOvdWse4I-C2NUQjVJVDlKS1c0SlhQSUxLNVBaOEZCNUczVS4u).]_

## Related documents

* [Open Practices](open_practices.md)
* [Rules of Behavior](rules_of_behavior.md)
* [Thanks and Acknowledgements](thanks.md)
* [Disclaimer](DISCLAIMER.md)
* [Contribution Notice](CONTRIBUTING.md)
* [Code of Conduct](code-of-conduct.md)

## Overview

Describe the purpose of your project. Add additional sections as necessary to help collaborators and potential collaborators understand and use your project.
  
## Public Domain Standard Notice
This repository constitutes a work of the United States Government and is not
subject to domestic copyright protection under 17 USC § 105. This repository is in
the public domain within the United States, and copyright and related rights in
the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).
All contributions to this repository will be released under the CC0 dedication. By
submitting a pull request you are agreeing to comply with this waiver of
copyright interest.

## License Standard Notice
The repository utilizes code licensed under the terms of the Apache Software
License and therefore is licensed under ASL v2 or later.

This source code in this repository is free: you can redistribute it and/or modify it under
the terms of the Apache Software License version 2, or (at your option) any
later version.

This source code in this repository is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the Apache Software License for more details.

You should have received a copy of the Apache Software License along with this
program. If not, see http://www.apache.org/licenses/LICENSE-2.0.html

The source code forked from other open source projects will inherit its license.

## Privacy Standard Notice
This repository contains only non-sensitive, publicly available data and
information. All material and community participation is covered by the
[Disclaimer](DISCLAIMER.md)
and [Code of Conduct](code-of-conduct.md).
For more information about CDC's privacy policy, please visit [http://www.cdc.gov/other/privacy.html](https://www.cdc.gov/other/privacy.html).

## Contributing Standard Notice
Anyone is encouraged to contribute to the repository by [forking](https://help.github.com/articles/fork-a-repo)
and submitting a pull request. (If you are new to GitHub, you might start with a
[basic tutorial](https://help.github.com/articles/set-up-git).) By contributing
to this project, you grant a world-wide, royalty-free, perpetual, irrevocable,
non-exclusive, transferable license to all users under the terms of the
[Apache Software License v2](http://www.apache.org/licenses/LICENSE-2.0.html) or
later.

All comments, messages, pull requests, and other submissions received through
CDC including this GitHub page may be subject to applicable federal law, including but not limited to the Federal Records Act, and may be archived. Learn more at [http://www.cdc.gov/other/privacy.html](http://www.cdc.gov/other/privacy.html).

## Records Management Standard Notice
This repository is not a source of government records, but is a copy to increase
collaboration and collaborative potential. All government records will be
published through the [CDC web site](http://www.cdc.gov).

## Additional Standard Notices
Please refer to [CDC's Template Repository](https://github.com/CDCgov/template) for more information about [contributing to this repository](https://github.com/CDCgov/template/blob/main/CONTRIBUTING.md), [public domain notices and disclaimers](https://github.com/CDCgov/template/blob/main/DISCLAIMER.md), and [code of conduct](https://github.com/CDCgov/template/blob/main/code-of-conduct.md).