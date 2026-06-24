#!/usr/bin/env python3
"""
summary_report.py — Aggregate all per-sample SARS-CoV-2 pipeline outputs into a
single summary TXT (tab-separated).

Usage:
    summary_report.py --qc-dir <dir> --coverage-dir <dir> --consensus-dir <dir>
                      --nextclade-dir <dir> --vadr-dir <dir> --pangolin-dir <dir>
                      --kraken2-dir <dir> --trimstat-dir <dir> --phix-log-dir <dir>
                      --sotc "S:L452R,S:E484K"
                      --output <summary_report.txt>

All directories can be '.' when files are staged flat in the work directory.

Output columns:
    sample_id, kraken2_percent,
    reference, start, end,
    num_raw_reads, num_clean_reads, num_mapped_reads, percent_mapped_clean_reads,
    cov_bases_mapped, percent_genome_cov_map, mean_depth, mean_base_qual, mean_map_qual,
    assembly_length, numN, percent_ref_genome_cov,
    nextclade_clade, pangolin_version, lineage, SOTC,
    vadr_flag, qc_flag
"""

import argparse
import csv
import glob
import os
import sys


# ---------------------------------------------------------------------------
# Loaders — each returns a dict keyed by sample_id (unless noted)
# ---------------------------------------------------------------------------

def load_coverage(coverage_dir):
    """Read *.coverage.txt (samtools coverage, post-ivar). {sample_id: stats}."""
    records = {}
    for path in glob.glob(os.path.join(coverage_dir, "*.coverage.txt")):
        sid = os.path.basename(path).replace(".coverage.txt", "")
        with open(path) as fh:
            _header = fh.readline()
            line = fh.readline().rstrip()
        if not line:
            continue
        cols = line.split("\t")
        if len(cols) < 9:
            continue
        records[sid] = {
            "reference":              cols[0],
            "start":                  cols[1],
            "end":                    cols[2],
            "num_mapped_reads":       cols[3],
            "cov_bases_mapped":       cols[4],
            "percent_genome_cov_map": cols[5],
            "mean_depth":             cols[6],
            "mean_base_qual":         cols[7],
            "mean_map_qual":          cols[8],
        }
    return records


def load_consensus(consensus_dir):
    """Read *.consensus.fa → {sample_id: {assembly_length, numN, _seq_called}}."""
    records = {}
    for path in glob.glob(os.path.join(consensus_dir, "*.consensus.fa")):
        sid = os.path.basename(path).replace(".consensus.fa", "")
        seq_parts = []
        with open(path) as fh:
            for line in fh:
                if not line.startswith(">"):
                    seq_parts.append(line.rstrip())
        seq = "".join(seq_parts).upper()
        records[sid] = {
            "assembly_length": str(len(seq)),
            "numN":            str(seq.count("N")),
            "_seq_called":     len(seq) - seq.count("N"),
        }
    return records


def load_nextclade(nextclade_dir):
    """Read *_nextclade.tsv → {seqName: row}."""
    records = {}
    for path in glob.glob(os.path.join(nextclade_dir, "*_nextclade.tsv")):
        with open(path, newline="") as fh:
            reader = csv.DictReader(fh, delimiter="\t")
            for row in reader:
                sid = (row.get("seqName") or "").strip()
                if sid:
                    records[sid] = row
    return records


def load_vadr(vadr_dir):
    """Walk VADR result dirs → {sample_id: 'PASS'|'REVIEW'}."""
    records = {}
    for pass_list in glob.glob(os.path.join(vadr_dir, "**", "*.vadr.pass.list"), recursive=True):
        with open(pass_list) as fh:
            for line in fh:
                sid = line.strip()
                if sid:
                    records[sid] = "PASS"
    for fail_list in glob.glob(os.path.join(vadr_dir, "**", "*.vadr.fail.list"), recursive=True):
        with open(fail_list) as fh:
            for line in fh:
                sid = line.strip()
                if sid and sid not in records:
                    records[sid] = "REVIEW"
    return records


def load_kraken2(kraken2_dir):
    """
    Parse *_kraken2_report.txt; report the percentage of reads at the most
    specific available SARS-CoV-2 taxon. {sample_id: '42.35'}.
    """
    KW_PRIORITY = (
        "severe acute respiratory syndrome coronavirus 2",
        "severe acute respiratory syndrome-related coronavirus",
        "betacoronavirus",
    )
    records = {}
    for path in glob.glob(os.path.join(kraken2_dir, "*_kraken2_report.txt")):
        sid = os.path.basename(path).replace("_kraken2_report.txt", "")
        lines = []
        try:
            with open(path) as fh:
                for line in fh:
                    cols = line.rstrip("\n").split("\t")
                    if len(cols) < 6:
                        continue
                    try:
                        pct = float(cols[0].strip())
                    except ValueError:
                        continue
                    lines.append((pct, cols[5].strip().lower()))
        except OSError:
            pass
        value = "0.00"
        for kw in KW_PRIORITY:
            matches = [pct for pct, name in lines if kw in name]
            if matches:
                value = f"{round(max(matches), 2):.2f}"
                break
        records[sid] = value
    return records


def load_trimstats(trimstat_dir):
    """Parse *_trimstats.txt (trimmomatic). 'Input Read Pairs: N' → N*2."""
    import re
    records = {}
    for path in glob.glob(os.path.join(trimstat_dir, "*_trimstats.txt")):
        sid = os.path.basename(path).replace("_trimstats.txt", "")
        try:
            with open(path) as fh:
                content = fh.read()
            m = re.search(r'Input Read Pairs:\s+(\d+)', content)
            if m:
                records[sid] = str(int(m.group(1)) * 2)
        except OSError:
            pass
    return records


def load_phix_log(phix_log_dir):
    """Parse *_phix_log.txt (bbduk). 'Result:  N reads' → clean read count."""
    import re
    records = {}
    for path in glob.glob(os.path.join(phix_log_dir, "*_phix_log.txt")):
        sid = os.path.basename(path).replace("_phix_log.txt", "")
        try:
            with open(path) as fh:
                content = fh.read()
            m = re.search(r'Result:\s+(\d+)\s+reads', content)
            if m:
                records[sid] = str(int(m.group(1)))
        except OSError:
            pass
    return records


def load_qc(qc_dir):
    """Read *_qc.tsv → {sample_id: qc_flag}."""
    records = {}
    for path in glob.glob(os.path.join(qc_dir, "*_qc.tsv")):
        with open(path, newline="") as fh:
            reader = csv.DictReader(fh, delimiter="\t")
            for row in reader:
                sid = (row.get("sample_id") or "").strip()
                if sid:
                    records[sid] = (row.get("qc_flag") or "NA").strip()
    return records


def load_pangolin(pangolin_dir):
    """Read *_lineage_report.csv → {sample_id: {lineage, pangolin_version}}."""
    records = {}
    for path in glob.glob(os.path.join(pangolin_dir, "*_lineage_report.csv")):
        sid = os.path.basename(path).replace("_lineage_report.csv", "")
        try:
            with open(path, newline="") as fh:
                row = next(csv.DictReader(fh), None)
        except OSError:
            row = None
        if not row:
            continue
        lineage = (row.get("lineage") or "").strip() or "NA"
        psoft   = (row.get("pangolin_version") or "").strip()
        pdata   = (row.get("version") or "").strip()
        if psoft and pdata:
            version = f"{psoft}_pdata-{pdata}"
        elif psoft:
            version = psoft
        else:
            version = "NA"
        records[sid] = {"lineage": lineage, "pangolin_version": version}
    return records


def screen_sotc(nc_row, sotc_list):
    """Match params.sotc tokens against the Nextclade v3 aaSubstitutions field."""
    if not nc_row or not sotc_list:
        return ""
    subs = (nc_row.get("aaSubstitutions") or "").replace(" ", "")
    present = {t for t in subs.split(",") if t}
    matched = [s for s in sotc_list if s in present]
    return ",".join(matched)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Aggregate SARS-CoV-2 pipeline results into summary TXT")
    parser.add_argument("--qc-dir",        required=True)
    parser.add_argument("--coverage-dir",  required=True)
    parser.add_argument("--consensus-dir", required=True)
    parser.add_argument("--nextclade-dir", required=True)
    parser.add_argument("--vadr-dir",      required=True)
    parser.add_argument("--pangolin-dir",  required=True)
    parser.add_argument("--kraken2-dir",   required=True)
    parser.add_argument("--trimstat-dir",  required=True)
    parser.add_argument("--phix-log-dir",  required=True)
    parser.add_argument("--sotc",          default="", help="Comma-separated mutations to screen (e.g. S:L452R,S:E484K)")
    parser.add_argument("--output",        required=True)
    args = parser.parse_args()

    sotc_list = [s.strip() for s in args.sotc.split(",") if s.strip()]

    qc        = load_qc(args.qc_dir)
    coverage  = load_coverage(args.coverage_dir)
    consensus = load_consensus(args.consensus_dir)
    nextclade = load_nextclade(args.nextclade_dir)
    vadr      = load_vadr(args.vadr_dir)
    pangolin  = load_pangolin(args.pangolin_dir)
    kraken2   = load_kraken2(args.kraken2_dir)
    trimstats = load_trimstats(args.trimstat_dir)
    phix_log  = load_phix_log(args.phix_log_dir)

    all_samples = sorted(
        set(qc) | set(coverage) | set(consensus)
        | set(kraken2) | set(trimstats) | set(phix_log)
    )

    header = [
        "sample_id", "kraken2_percent",
        "reference", "start", "end",
        "num_raw_reads", "num_clean_reads", "num_mapped_reads", "percent_mapped_clean_reads",
        "cov_bases_mapped", "percent_genome_cov_map", "mean_depth", "mean_base_qual", "mean_map_qual",
        "assembly_length", "numN", "percent_ref_genome_cov",
        "nextclade_clade", "pangolin_version", "lineage", "SOTC",
        "vadr_flag", "qc_flag",
    ]

    if not all_samples:
        with open(args.output, "w", newline="") as out:
            csv.writer(out, delimiter="\t").writerow(header)
        print("WARNING: no samples found — wrote header-only report", file=sys.stderr)
        return

    rows = []
    for sid in all_samples:
        cov  = coverage.get(sid, {})
        con  = consensus.get(sid, {})
        nc   = nextclade.get(sid, {})
        vf   = vadr.get(sid, "NA")
        k2   = kraken2.get(sid, "NA")
        qf   = qc.get(sid, "NA")
        pang = pangolin.get(sid, {})

        # QC-failed samples never reach VADR; report FAIL (not NA) so the
        # qc_flag/vadr_flag pair is unambiguous.
        if vf == "NA" and qf.startswith("FAIL"):
            vf = "FAIL"

        raw_reads   = trimstats.get(sid, "NA")
        clean_reads = phix_log.get(sid, "NA")

        mapped = cov.get("num_mapped_reads", "NA")
        if mapped != "NA" and clean_reads != "NA":
            try:
                pct_mapped = f"{float(mapped) / float(clean_reads) * 100:.4f}"
            except (ValueError, ZeroDivisionError):
                pct_mapped = "NA"
        else:
            pct_mapped = "NA"

        ref_len = int(cov.get("end", 0) or 0)
        called  = con.get("_seq_called", 0)
        pct_ref = f"{(called / ref_len * 100):.4f}" if (ref_len > 0 and con) else "NA"

        clade = nc.get("clade") or nc.get("clade_nextstrain") or ("NA" if not nc else "unassigned")

        rows.append({
            "sample_id":                  sid,
            "kraken2_percent":            k2,
            "reference":                  cov.get("reference", "NA"),
            "start":                      cov.get("start", "NA"),
            "end":                        cov.get("end", "NA"),
            "num_raw_reads":              raw_reads,
            "num_clean_reads":            clean_reads,
            "num_mapped_reads":           mapped,
            "percent_mapped_clean_reads": pct_mapped,
            "cov_bases_mapped":           cov.get("cov_bases_mapped", "NA"),
            "percent_genome_cov_map":     cov.get("percent_genome_cov_map", "NA"),
            "mean_depth":                 cov.get("mean_depth", "NA"),
            "mean_base_qual":             cov.get("mean_base_qual", "NA"),
            "mean_map_qual":              cov.get("mean_map_qual", "NA"),
            "assembly_length":            con.get("assembly_length", "NA"),
            "numN":                       con.get("numN", "NA"),
            "percent_ref_genome_cov":     pct_ref,
            "nextclade_clade":            clade,
            "pangolin_version":           pang.get("pangolin_version", "NA"),
            "lineage":                    pang.get("lineage", "NA"),
            "SOTC":                       screen_sotc(nc, sotc_list) if nc else "NA",
            "vadr_flag":                  vf,
            "qc_flag":                    qf,
        })

    with open(args.output, "w", newline="") as out:
        writer = csv.DictWriter(out, fieldnames=header, delimiter="\t")
        writer.writeheader()
        writer.writerows(rows)

    print(f"Summary report written: {args.output} ({len(rows)} samples)", file=sys.stderr)


if __name__ == "__main__":
    main()
