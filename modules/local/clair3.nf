process CLAIR3 {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/clair3:0.1.10--hdfd78af_0':
        'biocontainers/clair3:0.1.10--hdfd78af_0' }"
        

    input:
    tuple val(meta), path(bam)
    tuple val(meta2), path(fasta)
    //tuple val(meta3), path(bed)
    path(bed)

    output:
    tuple val(meta), path("*.vcf"), emit: vcf_ch
    tuple val(meta), path("*.vcf.gz*"), optional: true, emit: vcf_gz_ch
    //tuple val(meta), path("*pileup.vcf.gz"), emit: pileup_vcf_gz
    //tuple val(meta), path("*full_alignment.vcf.gz"), emit: alignment_vcf_gz
    //tuple val(meta), path("*merge_output.vcf.gz"), emit: merge_vcf_gz
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    run_clair3.sh \\
        --bam_fn=$bam \\
        --ref_fn=$fasta \\
        $args \\
        --platform="ont" \\
        --threads=$task.cpus \\
        --model_path=/opt/models/r941_prom_sup_g5014 \\
        --bed_fn=$bed \\
        -o ${prefix} \\
        

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        run_clair3.sh: \$(run_clair3.sh --version |& sed '1!d ; s/Clair3 //')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    /*
    """
    touch ${prefix}.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        clair3: \$(samtools --version |& sed '1!d ; s/samtools //')
    END_VERSIONS
    """*/
}
