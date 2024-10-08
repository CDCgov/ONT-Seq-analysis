/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PRINT PARAMS SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryLog; paramsSummaryMap } from 'plugin/nf-validation'

def logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
def citation = '\n' + WorkflowMain.citation(workflow) + '\n'
def summary_params = paramsSummaryMap(workflow)

// Print parameter summary log to screen
log.info logo + paramsSummaryLog(workflow) + citation

WorkflowMpoxseqanalysis.initialise(params, log)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/input_check'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { FASTQC                      } from '../modules/nf-core/fastqc/main'
include { MULTIQC                     } from '../modules/nf-core/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'
include { SEQTK_TRIM                  } from '../modules/nf-core/seqtk/trim/main'
include { TRIMMOMATIC                 } from '../modules/nf-core/trimmomatic/main'
include { MINIMAP2_INDEX              } from '../modules/nf-core/minimap2/index/main'
include { MINIMAP2_ALIGN              } from '../modules/nf-core/minimap2/align/main'
include { SAMTOOLS_INDEX              } from '../modules/nf-core/samtools/index/main'
include { SAMTOOLS_SORT               } from '../modules/nf-core/samtools/sort/main'
include { SAMTOOLS_DEPTH              } from '../modules/nf-core/samtools/depth/main'
include { SAMTOOLS_VIEW               } from '../modules/nf-core/samtools/view/main'
include { IVAR_CONSENSUS              } from '../modules/nf-core/ivar/consensus/main'
include { BEDOPS_CONVERT2BED          } from '../modules/nf-core/bedops/convert2bed/main'
include { SAMTOOLS_FAIDX              } from '../modules/nf-core/samtools/faidx/main'
include { IVAR_VARIANTS               } from '../modules/nf-core/ivar/variants/main'
include { BCFTOOLS_INDEX              } from '../modules/nf-core/bcftools/index/main'
include { NEXTCLADE_DATASETGET        } from '../modules/nf-core/nextclade/datasetget/main'
include { NEXTCLADE_RUN               } from '../modules/nf-core/nextclade/run/main'

//
// MODULE: Installed locally mirrored after nf-core/modules
//
include { MEDAKAMODULE as MEDAKA      } from '../modules/local/medakamodule'
//include { CLAIR3                      } from '../modules/local/clair3'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow MPOXSEQANALYSIS {

    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        file(params.input)
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    //
    // MODULE: Sequencing Toolkit (SEQTK) Trim & Trimmomatic
    //
    SEQTK_TRIM (
       INPUT_CHECK.out.reads
    )

    ch_trimemd_seq_se  = SEQTK_TRIM.out.reads
    ch_versions = ch_versions.mix(SEQTK_TRIM.out.versions)

    //
    // MODULE: TRIMMOMATIC
    //
    
    TRIMMOMATIC (
       ch_trimemd_seq_se
    )
    ch_trimmomatic  = TRIMMOMATIC.out.trimmed_reads
    ch_versions = ch_versions.mix(TRIMMOMATIC.out.versions)
    


 /*   Channel
        .fromPath(params.fasta) // Reference file provided via --fasta
        .set { fasta_alone_ch }
        
    Channel
        .fromPath(params.fasta) // Channel for reference_seq
        .map { reference_seq ->
            def meta = [:] // Empty meta, or you could use null if needed
            tuple(meta, reference_seq) // Add empty meta to the tuple for the reference_seq channel
        }
        .set { fasta_ch }
*/
    Channel
        .fromPath(params.fasta) // Channel for reference_seq
        .map { reference_seq ->
            def meta = [:] // Create an empty map for meta
            meta.file_name = reference_seq.getBaseName() // Extract the file name and add it to meta
            tuple(meta, reference_seq) // Add meta (with file name) and reference_seq to the tuple
        }
        .set { fasta_ch }
    //fasta_ch.view()

    //
    // Module: Minimap2 (index & align)
    //

    //MINIMAP2_INDEX(
    //    fasta_ch 
        // alternative: [ [], params.fasta ]
    //)

    //SAMTOOLS_FAIDX (
    //    fasta_ch,
    //    [ [], params.mmi_file ] //MINIMAP2_INDEX.out.index
    //)

    //ch_versions = ch_versions.mix(MINIMAP2_INDEX.out.versions)
    //ch_versions = ch_versions.mix(SAMTOOLS_FAIDX.out.versions)

    MINIMAP2_ALIGN (
        TRIMMOMATIC.out.trimmed_reads,
        [ [], params.mmi_file ], //MINIMAP2_INDEX.out.index,
        true, true, false, false
    )

    ch_minimap2_mapped = MINIMAP2_ALIGN.out.bam
    //ch_minimap2_mapped.view()
    ch_versions = ch_versions.mix(MINIMAP2_ALIGN.out.versions)


    //
    // MODULE: Samtools
    //

    SAMTOOLS_SORT(
        MINIMAP2_ALIGN.out.bam,
        [ [], params.fasta ]
    )

    
    SAMTOOLS_INDEX(
        SAMTOOLS_SORT.out.bam
    )

    SAMTOOLS_DEPTH(
        SAMTOOLS_SORT.out.bam,
        [[], []]
    )


    ch_versions = ch_versions.mix(SAMTOOLS_SORT.out.versions)
    ch_versions = ch_versions.mix(SAMTOOLS_INDEX.out.versions)
    ch_versions = ch_versions.mix(SAMTOOLS_DEPTH.out.versions.first())

    //
    // MODULE: Ivar consensus % Polish with Medaka
    //

    IVAR_CONSENSUS(
        SAMTOOLS_SORT.out.bam,
        [ params.fasta ],
        false
    )

    ch_versions = ch_versions.mix(IVAR_CONSENSUS.out.versions.first())
    
    ch_ivar_consensus = IVAR_CONSENSUS.out.fasta
    //.map { meta, file -> file } // Access the second element which is the path(".fa") from ivar

    //
    // MODULE: Medaka
    //
   

    MEDAKA (
        TRIMMOMATIC.out.trimmed_reads,
        IVAR_CONSENSUS.out.fasta
    )

    ch_versions = ch_versions.mix(MEDAKA.out.versions.first())

    println "MEDAKA.out.assembly: ${MEDAKA.out.assembly == null ? 'null' : 'valid'}"
    println "DEBUG: Type of MEDAKA.out.assembly: ${MEDAKA.out.assembly.getClass()}"
    MEDAKA.out.assembly.view()  // Print contents


    // 
    // MODULE: IVAR_VARIANTS & BCFTOOLS_INDEX (for indexing VCF file)
    //

    IVAR_VARIANTS (
        SAMTOOLS_SORT.out.bam,
        params.fasta,
        params.fai_file,
        params.gff_file,
        false
    )

    NEXTCLADE_DATASETGET (
        params.nextclade_dataset_name,
        []
    )

    NEXTCLADE_RUN (
        MEDAKA.out.assembly,
        NEXTCLADE_DATASETGET.out.dataset
    )

    ch_versions = ch_versions.mix(NEXTCLADE_DATASETGET.out.versions.first())
    ch_versions = ch_versions.mix(NEXTCLADE_RUN.out.versions.first())
    
    //BCFTOOLS_INDEX (
     //   IVAR_VARIANTS.out.tsv
    //)
    //ch_versions = ch_versions.mix(IVAR_VARIANTS.out.versions.first())

    
    //
    // MODULE: Run FastQC
    //
    FASTQC (
        TRIMMOMATIC.out.trimmed_reads
    )
    ch_versions = ch_versions.mix(FASTQC.out.versions.first())

    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowMpoxseqanalysis.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    methods_description    = WorkflowMpoxseqanalysis.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description, params)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]}.ifEmpty([]))
    //ch_multiqc_files = ch_multiqc_files.mix(SAMTOOLS_DEPTH.out.tsv.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(ch_minimap2_mapped.collect{it[1]}.ifEmpty([]))

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )
    multiqc_report = MULTIQC.out.report.toList()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.dump_parameters(workflow, params)
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

workflow.onError {
    if (workflow.errorReport.contains("Process requirement exceeds available memory")) {
        println("🛑 Default resources exceed availability 🛑 ")
        println("💡 See here on how to configure pipeline: https://nf-co.re/docs/usage/configuration#tuning-workflow-resources 💡")
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
