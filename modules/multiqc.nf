process multiqc {
    tag "multiqc"
    publishDir "${params.output}/all_multiqc", mode: 'copy'

    input:
        path summary
    output:
        path("multiqc_report.html"), emit: report
        path("multiqc_data/"),       emit: data

    script:
    """
    multiqc ${params.output} --interactive --ignore "*/multiqc/*" --ignore "*/all_multiqc/*"
    """
}

process multiqc_sample {
    tag "${meta.id}"
    publishDir "${params.output}/${meta.id}/multiqc", mode: 'copy'

    input:
        tuple val(meta), path(fastqc_zips)
    output:
        tuple val(meta), path("${meta.id}_multiqc_report.html"), emit: report
        tuple val(meta), path("${meta.id}_multiqc_report_data"), emit: data

    script:
    def prefix = meta.id
    """
    multiqc . --interactive --filename ${prefix}_multiqc_report
    """
}
