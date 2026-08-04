process summary_report {
    tag "summary"
    publishDir { "${params.output}" }, mode: 'copy', pattern: 'summary_report.txt'

    input:
        val  barrier
        path qc_files
        path coverage_files
        path consensus_files
        path nextclade_files
        path vadr_dirs
        path pangolin_files
        path kraken2_reports
        path trimstat_files
        path phix_log_files
        path nextclade_version_file
    output:
        path "summary_report.txt", emit: report
        path "*_mqc.tsv",          emit: mqc_tables, optional: true

    script:
    """
    summary_report.py \\
        --qc-dir                 . \\
        --coverage-dir           . \\
        --consensus-dir          . \\
        --nextclade-dir          . \\
        --vadr-dir               . \\
        --pangolin-dir           . \\
        --kraken2-dir            . \\
        --trimstat-dir           . \\
        --phix-log-dir           . \\
        --sotc                   "${params.sotc}" \\
        --nextclade-version-file ${nextclade_version_file} \\
        --output                 summary_report.txt
    """
}
