process kraken2 {
    tag "${meta.id}"
    publishDir { "${params.output}/${meta.id}/kraken2" }, mode: 'copy'

    input:
        tuple val(meta), path(reads)
    output:
        tuple val(meta), path("${meta.id}_kraken2_report.txt"), emit: report

    script:
    """
    kraken2 \\
        --db /kraken2-db \\
        --threads ${task.cpus} \\
        --paired \\
        --output /dev/null \\
        --report ${meta.id}_kraken2_report.txt \\
        ${reads[0]} ${reads[1]}
    """
}
