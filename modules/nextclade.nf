process nextclade_download {
    storeDir "${params.assets_dir}/nextclade/sars-cov-2"

    output:
        path "nextclade_dataset",     emit: db
        path "nextclade_version.txt", emit: version

    script:
    """
    nextclade dataset get \\
        --name sars-cov-2 \\
        --output-dir nextclade_dataset

    # Record "<nextclade software>_dataset-<dataset tag>" for the summary report.
    ncver=\$(nextclade --version 2>/dev/null | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+' | head -n 1)
    tag=\$(tr -d '\\n' < nextclade_dataset/pathogen.json \\
        | grep -oE '"version"[[:space:]]*:[[:space:]]*\\{[^}]*"tag"[[:space:]]*:[[:space:]]*"[^"]*"' \\
        | grep -oE '"tag"[[:space:]]*:[[:space:]]*"[^"]*"' \\
        | head -n 1 \\
        | sed -E 's/^"tag"[[:space:]]*:[[:space:]]*"//; s/"\$//')
    [ -z "\$ncver" ] && ncver=unknown
    [ -z "\$tag" ]   && tag=unknown
    echo "\${ncver}_dataset-\${tag}" > nextclade_version.txt
    """
}

process nextclade {
    tag "${meta.id}"
    publishDir "${params.output}/${meta.id}/nextclade", mode: 'copy'

    input:
        tuple val(meta), path(consensus), path(dataset)
    output:
        tuple val(meta), path("${meta.id}_nextclade.tsv"), emit: tsv
        val meta,                                          emit: done

    script:
    def prefix = meta.id
    """
    nextclade run \\
        --input-dataset ${dataset} \\
        --output-tsv ${prefix}_nextclade.tsv \\
        ${consensus}
    """
}
