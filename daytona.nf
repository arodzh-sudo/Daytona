#!/usr/bin/env nextflow

/*
  Daytona
  Florida's BPHL Nextflow pipeline for SARS-CoV-2 NGS data analysis
  Authors: Sarah Schmedes, Yibo Dong, Arnold Rodriguez, Molly Mitchell
  Email: bphl-sebioinformatics@flhealth.gov
*/

nextflow.enable.dsl = 2

params.assets_dir = "${projectDir}/assets"

include { fastqc; fastqc_clean           } from './modules/fastqc.nf'
include { humanscrubber                  } from './modules/humanscrubber.nf'
include { trimmomatic                    } from './modules/trimmomatic.nf'
include { bbtools_adapters; bbtools_phix } from './modules/bbtools.nf'
include { kraken2                        } from './modules/kraken2.nf'
include { bwa                            } from './modules/bwa.nf'
include { samtools_bam                   } from './modules/samtools.nf'
include { samtools_coverage              } from './modules/samtools.nf'
include { samtools_mpileup               } from './modules/samtools.nf'
include { ivar_trim                      } from './modules/ivar.nf'
include { ivar_variants                  } from './modules/ivar.nf'
include { ivar_consensus                 } from './modules/ivar.nf'
include { qc_gate                        } from './modules/qc_gate.nf'
include { vadr                           } from './modules/vadr.nf'
include { pangolin                       } from './modules/pangolin.nf'
include { nextclade_download; nextclade  } from './modules/nextclade.nf'
include { summary_report                 } from './modules/summary_report.nf'
include { multiqc                        } from './modules/multiqc.nf'

def refFiles() {
    def fa = "${projectDir}/assets/reference/nCoV-2019.reference.fasta"
    return [fa, "${fa}.amb", "${fa}.ann", "${fa}.bwt",
            "${fa}.fai", "${fa}.pac", "${fa}.sa"].collect { p -> file(p) }
}

workflow {

    log.info """
    Daytona — BPHL SARS-CoV-2 NGS pipeline
    ==========================================================================
    input dir     : ${params.input}
    output dir    : ${params.output}
    assets        : ${projectDir}/assets
    primer scheme : ${params.primer_scheme}
    SOTC          : ${params.sotc}
    ==========================================================================
    """

    // FASTQ input channel - handles both *_{1,2}.fastq.gz and *_R{1,2}_*.fastq.gz naming
    ch_reads = channel.fromFilePairs(
        ["${params.input}/*_{1,2}.fastq.gz",
         "${params.input}/*_R{1,2}_*.fastq.gz"],
        checkIfExists: false
    )
    .map { id, files ->
        def clean_id = id.replaceAll(/_S\d+_L\d+$/, '')
        def meta     = [ id: clean_id, single_end: false ]
        [ meta, files ]
    }

    // SARS-CoV-2 reference (FASTA + bwa index) and annotation/primer assets
    ch_ref    = channel.value(refFiles())
    ch_ref_fa = channel.value(file("${projectDir}/assets/reference/nCoV-2019.reference.fasta"))
    ch_gff    = channel.value(file("${projectDir}/assets/annotations/GCF_009858895.2_ASM985889v3_genomic.gff"))
    ch_primer = channel.value(file("${projectDir}/assets/primers/${params.primer_scheme}.bed"))

    // QC & cleanup
    fastqc(ch_reads)
    humanscrubber(ch_reads)
    trimmomatic(humanscrubber.out.reads)
    bbtools_adapters(trimmomatic.out.reads)
    bbtools_phix(bbtools_adapters.out.reads)
    fastqc_clean(bbtools_phix.out.reads)

    // Taxonomic screen
    kraken2(bbtools_phix.out.reads)

    // Alignment to reference
    bwa(bbtools_phix.out.reads, ch_ref)
    samtools_bam(bwa.out.sam)

    // Primer trim + coverage
    ivar_trim(samtools_bam.out.bam.combine(ch_primer))
    samtools_coverage(ivar_trim.out.bam)

    // mpileup → variants + consensus
    samtools_mpileup(ivar_trim.out.bam.combine(ch_ref_fa))
    ivar_variants(samtools_mpileup.out.mpileup.combine(ch_ref_fa).combine(ch_gff))
    ivar_consensus(samtools_mpileup.out.mpileup)

    // QC gate (>= 80% genome, >= 100x depth)
    ch_qc_input = ivar_consensus.out.consensus.join(samtools_coverage.out.coverage)
    qc_gate(ch_qc_input)

    ch_qc_pass = qc_gate.out.qc
        .filter { _meta, qc_file ->
            def lines = qc_file.readLines()
            lines.size() > 1 && lines[1].split('\t')[1].trim() == 'PASS'
        }

    ch_pass_consensus = ch_qc_pass
        .map { meta, _qc -> [ meta.id, meta ] }
        .join( ivar_consensus.out.consensus.map { meta, f -> [ meta.id, f ] } )
        .map { _id, meta, consensus -> [ meta, consensus ] }

    // Typing & validation
    // VADR is gated by the QC threshold (GenBank submission needs a complete genome);
    // Pangolin and Nextclade run on every consensus so below-threshold genomes still
    // get a lineage, clade, and SOTC reported.
    vadr(ch_pass_consensus)
    pangolin(ivar_consensus.out.consensus)

    ch_nextclade       = nextclade_download()
    ch_nextclade_input = ivar_consensus.out.consensus.combine(ch_nextclade.db)
    nextclade(ch_nextclade_input)

    ch_barrier = vadr.out.done
        .mix(pangolin.out.done, nextclade.out.done)
        .map { _meta -> 1 }
        .collect()
        .map { _ids -> true }

    summary_report(
        ch_barrier,
        qc_gate.out.qc.map                 { _meta, f -> f }.collect().ifEmpty([]),
        samtools_coverage.out.coverage.map { _meta, f -> f }.collect().ifEmpty([]),
        ivar_consensus.out.consensus.map   { _meta, f -> f }.collect().ifEmpty([]),
        nextclade.out.tsv.map              { _meta, f -> f }.collect().ifEmpty([]),
        vadr.out.results.map               { _meta, f -> f }.collect().ifEmpty([]),
        pangolin.out.report.map            { _meta, f -> f }.collect().ifEmpty([]),
        kraken2.out.report.map             { _meta, f -> f }.collect().ifEmpty([]),
        trimmomatic.out.stats.map          { _meta, f -> f }.collect().ifEmpty([]),
        bbtools_phix.out.phix_log.map      { _meta, f -> f }.collect().ifEmpty([]),
        ch_nextclade.version
    )

    multiqc(summary_report.out.report)
}
