process humanscrubber {
    tag "${meta.id}"
    publishDir "${params.output}/${meta.id}/humanscrubber", mode: 'copy'

    input:
        tuple val(meta), path(reads)
    output:
        tuple val(meta), path("${meta.id}_R{1,2}_humanclean.fastq.gz"), emit: reads

    script:
    def prefix = meta.id
    """
    gzip -dc ${reads[0]} > ${prefix}_R1.fastq
    gzip -dc ${reads[1]} > ${prefix}_R2.fastq

    /opt/scrubber/scripts/scrub.sh -r \\
        -i ${prefix}_R1.fastq \\
        -o ${prefix}_R1_humanclean.fastq

    /opt/scrubber/scripts/scrub.sh -r \\
        -i ${prefix}_R2.fastq \\
        -o ${prefix}_R2_humanclean.fastq

    gzip ${prefix}_R1_humanclean.fastq
    gzip ${prefix}_R2_humanclean.fastq

    rm ${prefix}_R1.fastq ${prefix}_R2.fastq
    """
}
