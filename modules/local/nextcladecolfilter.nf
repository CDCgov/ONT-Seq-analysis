process NEXTCLADECOLFILTER {
    tag "$meta.id"
    label 'process_single'
    //shell '/bin/bash', '-euo', 'pipefail'

    //conda "conda-forge::r-argparse=0.7.2 conda-forge::r-dplyr=1.1.4"

    //container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //    'https://depot.galaxyproject.org/singularity/mulled-v2-1021c2bc41756fa99bc402f461dad0d1c35358c1:b0c847e4fb89c343b04036e33b2daa19c4152cf5-0' :
    //    'biocontainers/mulled-v2-1021c2bc41756fa99bc402f461dad0d1c35358c1:b0c847e4fb89c343b04036e33b2daa19c4152cf5-0' }"

    /*container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'quay.io/biocontainers/python:3.9--1' }"

    conda "conda-forge::python=3.8.3 conda-forge::pandas=1.3.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.8.3' :
        'biocontainers/python:3.8.3' }" //3.8.3*/

    input:
    tuple val(meta), path(csv)

    output:
    tuple val(meta), path("${prefix}_clean.csv")           , optional:true, emit: clean_csv
    //path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script: // This script is bundled with the pipeline, in ONT/mpoxseqanalysis/bin/
    
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    cleaning_nextclade_output.sh ${csv} ${prefix}_clean.csv

    
    """

    /*cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS*/
}
