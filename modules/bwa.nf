process bwa {
    tag "${meta.id}"

    input:
        tuple val(meta), path(reads)
        path ref_files
    output:
        tuple val(meta), path("${meta.id}.sam"), emit: sam

    script:
    def prefix = meta.id
    def ref_fa = ref_files instanceof List ? ref_files.find { f -> f.name.endsWith('.fasta') } : ref_files
    """
    bwa mem \\
        -t ${task.cpus} \\
        ${ref_fa} \\
        ${reads[0]} ${reads[1]} \\
        > ${prefix}.sam
    """
}
