process multiqc {
    tag "multiqc"
    publishDir "${params.output}/multiqc", mode: 'copy'

    input:
        path summary
    output:
        path("multiqc_report.html"), emit: report
        path("multiqc_data/"),       emit: data

    script:
    """
    multiqc ${params.output} --interactive
    """
}
