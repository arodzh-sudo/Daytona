process ivar_trim {
    tag "${meta.id}"
    publishDir { "${params.output}/${meta.id}/ivar" }, mode: 'copy'

    input:
        tuple val(meta), path(bam), path(bai), path(primer)
    output:
        tuple val(meta), path("${meta.id}.primertrim.sorted.bam"), path("${meta.id}.primertrim.sorted.bam.bai"), emit: bam

    script:
    def prefix = meta.id
    """
    ivar trim \\
        -i ${bam} \\
        -b ${primer} \\
        -p ${prefix}.primertrim \\
        -e

    samtools sort -@ ${task.cpus} ${prefix}.primertrim.bam -o ${prefix}.primertrim.sorted.bam
    samtools index ${prefix}.primertrim.sorted.bam

    rm ${prefix}.primertrim.bam
    """
}

process ivar_variants {
    tag "${meta.id}"
    publishDir { "${params.output}/${meta.id}/ivar" }, mode: 'copy'

    input:
        tuple val(meta), path(mpileup), path(reference), path(gff)
    output:
        tuple val(meta), path("${meta.id}.variants.tsv"), emit: variants

    script:
    def prefix = meta.id
    """
    cat ${mpileup} | ivar variants \\
        -r ${reference} \\
        -m 10 \\
        -p ${prefix}.variants \\
        -q 20 \\
        -t 0.25 \\
        -g ${gff}
    """
}

process ivar_consensus {
    tag "${meta.id}"
    publishDir { "${params.output}/${meta.id}/ivar" }, mode: 'copy'

    input:
        tuple val(meta), path(mpileup)
    output:
        tuple val(meta), path("${meta.id}.consensus.fa"), emit: consensus

    script:
    def prefix = meta.id
    """
    cat ${mpileup} | ivar consensus \\
        -t 0 \\
        -m 10 \\
        -n N \\
        -p ${prefix}.consensus

    # ivar names the sequence after the reference; rename to sample ID so
    # downstream tools (Nextclade, Pangolin, summary_report.py) match by sample ID
    sed -i "1s/^>.*/>${prefix}/" ${prefix}.consensus.fa
    """
}
