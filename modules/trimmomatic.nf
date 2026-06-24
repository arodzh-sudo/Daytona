process trimmomatic {
    tag "${meta.id}"
    publishDir "${params.output}/${meta.id}/trimmomatic", mode: 'copy'

    input:
        tuple val(meta), path(reads)
    output:
        tuple val(meta), path("${meta.id}_R{1,2}_trim.fastq.gz"), emit: reads
        tuple val(meta), path("${meta.id}_trimstats.txt"),         emit: stats

    script:
    def prefix = meta.id
    """
    trimmomatic PE \\
        -phred33 \\
        -threads ${task.cpus} \\
        -trimlog ${prefix}_trimlog.txt \\
        ${reads[0]} ${reads[1]} \\
        ${prefix}_R1_trim.fastq.gz ${prefix}_R1_unpaired.fastq.gz \\
        ${prefix}_R2_trim.fastq.gz ${prefix}_R2_unpaired.fastq.gz \\
        SLIDINGWINDOW:4:30 MINLEN:75 TRAILING:20 \\
        > ${prefix}_trimstats.txt 2>&1

    rm ${prefix}_R1_unpaired.fastq.gz ${prefix}_R2_unpaired.fastq.gz
    """
}
