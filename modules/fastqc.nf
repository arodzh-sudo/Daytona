process fastqc {
    tag "${meta.id}"
    publishDir "${params.output}/${meta.id}/fastqc", mode: 'copy'

    input:
        tuple val(meta), path(reads)
    output:
        tuple val(meta), path("*.zip"),  emit: zip
        tuple val(meta), path("*.html"), emit: html

    script:
    """
    fastqc \\
        --threads ${task.cpus} \\
        ${reads[0]} ${reads[1]}
    """
}

process fastqc_clean {
    tag "${meta.id}"
    publishDir "${params.output}/${meta.id}/fastqc_clean", mode: 'copy'

    input:
        tuple val(meta), path(reads)
    output:
        tuple val(meta), path("*.zip"),  emit: zip
        tuple val(meta), path("*.html"), emit: html

    script:
    """
    fastqc \\
        --threads ${task.cpus} \\
        ${reads[0]} ${reads[1]}
    """
}
