process samtools_bam {
    tag "${meta.id}"
    publishDir "${params.output}/${meta.id}/samtools", mode: 'copy'

    input:
        tuple val(meta), path(sam)
    output:
        tuple val(meta), path("${meta.id}.sorted.bam"), path("${meta.id}.sorted.bam.bai"), emit: bam

    script:
    def prefix = meta.id
    """
    # Filter unmapped, name-sort, fixmate, position-sort, dedup, final sort + index
    samtools view -F 4 -u -h -b ${sam} \\
        | samtools sort -n -o ${prefix}.namesorted.bam

    samtools fixmate -m ${prefix}.namesorted.bam ${prefix}.fixmate.bam

    samtools sort -o ${prefix}.positionsort.bam ${prefix}.fixmate.bam

    samtools markdup -r ${prefix}.positionsort.bam ${prefix}.dedup.bam

    samtools sort -@ ${task.cpus} -o ${prefix}.sorted.bam ${prefix}.dedup.bam

    samtools index ${prefix}.sorted.bam

    rm ${prefix}.namesorted.bam ${prefix}.fixmate.bam ${prefix}.positionsort.bam ${prefix}.dedup.bam
    """
}

process samtools_coverage {
    tag "${meta.id}"
    publishDir "${params.output}/${meta.id}/samtools", mode: 'copy'

    input:
        tuple val(meta), path(bam), path(bai)
    output:
        tuple val(meta), path("${meta.id}.coverage.txt"), emit: coverage

    script:
    def prefix = meta.id
    """
    samtools coverage ${bam} -o ${prefix}.coverage.txt
    """
}

process samtools_mpileup {
    tag "${meta.id}"
    publishDir "${params.output}/${meta.id}/samtools", mode: 'copy'

    input:
        tuple val(meta), path(bam), path(bai), path(reference)
    output:
        tuple val(meta), path("${meta.id}.mpileup"), emit: mpileup

    script:
    def prefix = meta.id
    """
    samtools mpileup \\
        -A \\
        -d 8000 \\
        --reference ${reference} \\
        -B \\
        -Q 0 \\
        -o ${prefix}.mpileup \\
        ${bam}
    """
}
