# Changelog

All notable changes to the Daytona pipeline will be documented in this file.

---

## [Unreleased] - modernization

Full rebuild of the legacy `flaq_sc2_humanclean2.nf` SARS-CoV-2 pipeline into the
BPHL GitHub SOP format.

Later additions:

- Per-sample MultiQC (`multiqc_sample`) over each sample's raw + clean FastQC, published to
  `output/<sample_id>/multiqc/`; the aggregate MultiQC output dir renamed to
  `output/all_multiqc/` and now runs with `--ignore "*/multiqc/*" --ignore "*/all_multiqc/*"`
  so it no longer re-ingests MultiQC report/data dirs
- `nextflow.config` compacted with regex `withName` selectors (`fastqc.*`, `bbtools.*`,
  `samtools.*`, `ivar.*`)

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
