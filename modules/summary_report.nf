process summary_report {
    tag "summary"
    publishDir "${params.output}", mode: 'copy'

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
    output:
        path "summary_report.txt", emit: report

    script:
    """
    summary_report.py \\
        --qc-dir        . \\
        --coverage-dir  . \\
        --consensus-dir . \\
        --nextclade-dir . \\
        --vadr-dir      . \\
        --pangolin-dir  . \\
        --kraken2-dir   . \\
        --trimstat-dir  . \\
        --phix-log-dir  . \\
        --sotc          "${params.sotc}" \\
        --output        summary_report.txt
    """
}
