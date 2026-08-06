process multiqc {
    tag "multiqc"
    publishDir { "${params.output}" }, mode: 'copy'

    input:
        path summary
        path multiqc_config
        path custom_css
        path nf_config
        path mqc_tables, stageAs: 'mqc_in/*'

    output:
        path("daytona_report.html"), emit: report

    script:
    """
    mkdir -p mqc_in
    cp mqc_in/*_mqc.tsv ${params.output}/ 2>/dev/null || true

    {
      echo "# id: 'daytona_versions'"
      echo "# section_name: 'Software Versions'"
      echo "# description: 'Tool versions from the container tags pinned in nextflow.config.'"
      echo "# plot_type: 'table'"
      echo "# pconfig:"
      echo "#     id: 'daytona_versions_table'"
      echo "#     col1_header: 'Software'"
      echo "#     no_violin: true"
      echo "#     rows_are_samples: false"
      echo "# headers:"
      echo "#     Version:"
      echo "#         scale: false"
      echo "#         format: '{}'"
      printf 'Software\\tVersion\\n'
      grep -hoE "docker://[^']+" ${nf_config} \\
        | sed -E 's#docker://[^/]*/([^:]+):(.+)#\\1\\t\\2#' \\
        | sort -u
    } > "${params.output}/daytona_versions_mqc.tsv"

    multiqc ${params.output} \\
        -c ${multiqc_config} \\
        --filename daytona_report.html \\
        --interactive \\
        --ignore "*/multiqc/*" \\
        --ignore "*daytona_report*" \\
        --ignore "*summary_report.txt"

    rm -f "${params.output}"/daytona_*_mqc.tsv
    """
}

process multiqc_sample {
    tag "${meta.id}"
    publishDir { "${params.output}/${meta.id}/multiqc" }, mode: 'copy'

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
