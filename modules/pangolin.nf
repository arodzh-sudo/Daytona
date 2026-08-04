process pangolin {
    tag "${meta.id}"
    publishDir { "${params.output}/${meta.id}/pangolin" }, mode: 'copy'

    input:
        tuple val(meta), path(consensus)
    output:
        tuple val(meta), path("${meta.id}_lineage_report.csv"), emit: report
        val meta,                                               emit: done

    script:
    def prefix = meta.id
    """
    pangolin ${consensus} \\
        --outfile ${prefix}_lineage_report.csv \\
        --threads ${task.cpus}
    """
}
