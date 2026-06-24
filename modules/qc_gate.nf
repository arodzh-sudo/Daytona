process qc_gate {
    tag "${meta.id}"

    input:
        tuple val(meta), path(consensus), path(coverage)
    output:
        tuple val(meta), path("${meta.id}_qc.tsv"), emit: qc

    script:
    def prefix = meta.id
    """
    qc_gate.py \\
        --sample-id ${prefix} \\
        --consensus ${consensus} \\
        --coverage  ${coverage} \\
        --output    ${meta.id}_qc.tsv
    """
}
