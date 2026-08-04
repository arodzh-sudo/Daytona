process fastqc {
    tag "${meta.id}"
    publishDir { "${params.output}/${meta.id}/fastqc" }, mode: 'copy'

    input:
        tuple val(meta), path(reads)
    output:
        tuple val(meta), path("*.zip"),  emit: zip
        tuple val(meta), path("*.html"), emit: html

    script:
    def prefix = meta.id
    """
    # MultiQC keys FastQC rows off the Filename inside fastqc_data.txt, so the input must carry the canonical name
    ln -s ${reads[0]} ${prefix}_R1_raw.fastq.gz
    ln -s ${reads[1]} ${prefix}_R2_raw.fastq.gz

    fastqc \\
        --threads ${task.cpus} \\
        ${prefix}_R1_raw.fastq.gz ${prefix}_R2_raw.fastq.gz
    """
}

process fastqc_clean {
    tag "${meta.id}"
    publishDir { "${params.output}/${meta.id}/fastqc_clean" }, mode: 'copy'

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
