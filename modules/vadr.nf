process vadr {
    tag "${meta.id}"
    publishDir "${params.output}/${meta.id}/vadr",    mode: 'copy', pattern: "*_vadr_results"
    publishDir "${params.output}/assemblies_qc_pass", mode: 'copy', pattern: "*.consensus.fasta"

    input:
        tuple val(meta), path(consensus)
    output:
        tuple val(meta), path("${meta.id}_vadr_results/"),     emit: results
        path "${meta.id}.consensus.fasta", optional: true,     emit: pass_fasta
        val meta,                                              emit: done

    script:
    def prefix = meta.id
    """
    fasta-trim-terminal-ambigs.pl \\
        --minlen 50 \\
        --maxlen 30000 \\
        ${consensus} \\
        > ${prefix}.trimmed.fasta

    v-annotate.pl \\
        --split \\
        --cpu ${task.cpus} \\
        --glsearch \\
        -s -r \\
        --nomisc \\
        --lowsim5seq 6 \\
        --lowsim3seq 6 \\
        --alt_fail lowscore,insertnn,deletinn \\
        --mkey sarscov2 \\
        --mdir /opt/vadr/vadr-models/ \\
        ${prefix}.trimmed.fasta \\
        ${prefix}_vadr_results

    pass_fa=\$(find ${prefix}_vadr_results -name '*.vadr.pass.fa' | head -n 1)
    if [ -s "\$pass_fa" ]; then
        cp "\$pass_fa" ${prefix}.consensus.fasta
    fi
    """
}
