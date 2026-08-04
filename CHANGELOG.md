# Changelog

All notable changes to the Daytona pipeline will be documented in this file.

---

## [Unreleased] - modernization

Full rebuild of the legacy `flaq_sc2_humanclean2.nf` SARS-CoV-2 pipeline into the
BPHL GitHub SOP format.

Later additions:

- Per-sample MultiQC (`multiqc_sample`) over each sample's raw + clean FastQC, published to
  `output/<sample_id>/multiqc/`
- `nextflow.config` compacted with regex `withName` selectors (`fastqc.*`, `bbtools.*`,
  `samtools.*`, `ivar.*`)
- `assets/multiqc_config.yaml` and `assets/daytona_report.css`: branded, interactive run-level
  dashboard (`output/daytona_report.html`) replacing the generic aggregate report. The run-level
  `multiqc` process stages the config, CSS and custom tables, writes an inline Software Versions
  table from the container tags pinned in `nextflow.config`, and removes the `_mqc.tsv` files
  after each run so a resumed run does not re-ingest stale tables
- `bin/summary_report.py`: `_mqc_preamble`/`_write_mqc`/`emit_daytona_mqc_tables` write
  `daytona_lineage_mqc.tsv` and `daytona_assembly_mqc.tsv`, rendered as sortable, color-coded
  tables in the dashboard. SOTC stays a `summary_report.txt` column and is not shown there
- `modules/fastqc.nf`: the `fastqc` process symlinks its inputs to `<sample>_R{1,2}_raw.fastq.gz`
  before running, so raw and clean reads collapse onto one General Statistics row per sample
  instead of two. MultiQC keys FastQC rows off the `Filename` recorded inside `fastqc_data.txt`,
  which follows the input name, so renaming the output zip has no effect
- `.gitattributes` to enforce LF line endings
- All 20 `publishDir` directives across `modules/*.nf` rewritten from bare-string to closure
  form (`publishDir { "..." }, mode: 'copy'`), required by the v2 strict script parser that
  Nextflow 26.04 makes the default. The bare-string form evaluates the path at
  process-definition time, before `meta` is in scope, raising `No such variable: meta` at
  module load. The pipeline now runs on Nextflow 23.04 through 26.x
- `daytona.nf`: the read channel gets `.ifEmpty { error(...) }`, so an input directory with no
  matching FASTQ files aborts immediately instead of exiting 0 having done nothing; `ch_barrier`
  gets `.ifEmpty(true)`, so a run where no sample reaches VADR, Pangolin or Nextclade still
  triggers `summary_report` instead of stalling
- `bin/summary_report.py`: `percent_genome_cov_map` renamed to `percent_genome_cov_aligned`
  (breadth of coverage from the mapped BAM) and `percent_ref_genome_cov` renamed to
  `percent_genome_cov_assembled` (completeness of the final iVar consensus, the value `qc_flag`
  is thresholded on). These are the names `Daytona_dengue` and `Daytona_chikv` use
- `bin/summary_report.py`: exits nonzero when `samtools_coverage`, `ivar_consensus`, `qc_gate`,
  `nextclade`, `pangolin` or `vadr` produced zero successful outputs across every sample that
  reached them. Those processes run under `errorStrategy = 'ignore'`, which otherwise reports a
  broken container, a missing reference or a bad mount the same way it reports one sample's low
  coverage. VADR is checked against QC-pass samples only, since it is gated on them
- `modules/summary_report.nf`: emits `*_mqc.tsv` on a channel and scopes `publishDir` to
  `summary_report.txt`, so the dashboard tables never land in the output directory
- `nextflow.config`: `env._JAVA_OPTIONS = "-XX:-UsePerfData"` stops the JVM writing hsperfdata,
  which crashes FastQC, Trimmomatic and BBTools tasks when `/tmp` is full
- `daytona.sh`: loads the default `nextflow` module instead of pinning `nextflow/25.10.4`
- `README.md`: Nextflow support range updated to 23.04-26.x; workflow diagram condensed into
  pipeline-stage categories; output section documents `daytona_report.html`

### Added

- `daytona.nf` — entry workflow; `meta`-driven, staged-file channel design replacing the
  monolithic `flaq_sc2_humanclean2.nf` (which passed filesystem path strings between processes)
- `nextflow.config` — single config; per-tool `withName` `container`/`cpus`/`memory`; profiles
  for `standard`, `docker`, `singularity`, `apptainer`; `params.primer_scheme` and `params.sotc`
- `modules/` — one `.nf` per tool: `fastqc`, `humanscrubber`, `trimmomatic`, `bbtools`,
  `multiqc`, `kraken2`, `bwa`, `samtools` (`samtools_bam`/`samtools_coverage`/`samtools_mpileup`),
  `ivar` (`ivar_trim`/`ivar_variants`/`ivar_consensus`), `qc_gate`, `vadr`, `pangolin`,
  `nextclade` (`nextclade_download`/`nextclade`), `summary_report`
- `modules/kraken2.nf` — **new** taxonomic/contamination screen (viral DB), reported as
  `kraken2_percent`
- `modules/nextclade.nf` — Nextclade **v3** with `nextclade dataset get --name sars-cov-2` and
  `storeDir` caching, replacing the dead `nextclade_2021-03-15.sif` run on a concatenated FASTA
- `bin/qc_gate.py` — QC gate (≥80% genome, ≥100x depth); 2-column TSV consumed by the workflow filter
- `bin/summary_report.py` — aggregates per-sample stats into `summary_report.txt`; includes inline
  Pangolin lineage/version parsing, Kraken2 SARS-CoV-2 percentage, and SOTC screening from the
  Nextclade v3 `aaSubstitutions` field
- `assets/` — `reference/` (FASTA + bwa index), `annotations/` (GFF), `primers/` (ARTIC BEDs)
- `daytona.sh` — SLURM submission script (`module load conda apptainer nextflow`,
  `NXF_APPTAINER_CACHEDIR`, timestamp rename block)
- `CHANGELOG.md`

### Changed

- Alignment **always deduplicates** (the legacy `params.frag` toggle is removed); split into
  `bwa` (align) + `samtools_bam` (filter → name-sort → fixmate → markdup -r → sort → index)
- VADR uses the in-container `sarscov2` model at `/opt/vadr/vadr-models-sarscov2`
  (`--mkey sarscov2`, `staphb/vadr:1.7`); no model download is required
- QC gate now gates **only VADR**; Pangolin and Nextclade run on all consensus so
  below-threshold genomes still receive lineage/clade/SOTC. QC-failed samples report
  `qc_flag = FAIL` and `vadr_flag = FAIL`
- `summary_report.txt` columns reordered (`kraken2_percent` and the `nextclade_*` columns moved
  to the end) and a `nextclade_version` column added — Nextclade software version + dataset tag
  (e.g. `3.21.2_dataset-<tag>`), captured once in `nextclade_download` from `pathogen.json`
- `qc_gate` no longer publishes a per-sample `qc/` directory; `_qc.tsv` is intermediate-only
  (consumed by the PASS filter and the summary report)
- All embedded-Python logic in the legacy `pystats` process moved to `bin/` scripts
- Reference/primer/GFF assets moved from `reference/` and `primers/` into `assets/`
- GFF sequence ID normalized from `NC_045512.2` to `MN908947.3` to match the reference FASTA and
  ARTIC primer BEDs, so `ivar variants -g` annotates amino-acid changes (the legacy pipeline had a
  silent seqid mismatch that suppressed annotation)
- Per-sample `report.txt` + sbatch `sort|uniq|sed` aggregation replaced by an in-pipeline,
  barrier-synchronized `summary_report.txt`

### Removed

- `flaq_sc2_nf.nf`, `flaq_sc2_humanclean.nf`, `flaq_sc2_humanclean2.nf` — replaced by `daytona.nf`
  and the `modules/` directory
- `sbatch_flaq_sc2_nf.sh` — replaced by `daytona.sh`
- Hardcoded `/apps/staphb-toolkit/containers/*.sif` `singularity exec` calls — containers now
  declared per process in `nextflow.config`
