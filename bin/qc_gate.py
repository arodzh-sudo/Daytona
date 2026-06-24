#!/usr/bin/env python3
"""
qc_gate.py — Compute QC pass/fail for a SARS-CoV-2 consensus assembly.

Reads samtools coverage output and the consensus FASTA.
Writes a 2-column TSV: sample_id, qc_flag.

QC thresholds (genome breadth checked first, then depth — matching the
legacy flaq_sc2 pipeline precedence):
    percent_ref_genome_cov >= 80%  AND  mean_depth >= 100x  -> PASS
"""

import argparse
import sys

QC_MIN_COVERAGE = 80.0
QC_MIN_DEPTH    = 100.0


def parse_coverage(path):
    with open(path) as fh:
        _header = fh.readline()
        line = fh.readline().rstrip()
    fields = line.split('\t')
    return fields[2], fields[6]   # end, meandepth


def parse_consensus(path):
    seq_lines = []
    with open(path) as fh:
        for line in fh:
            if not line.startswith('>'):
                seq_lines.append(line.rstrip())
    seq = ''.join(seq_lines).upper()
    return len(seq), seq.count('N')


def main():
    parser = argparse.ArgumentParser(description='QC gate for SARS-CoV-2 consensus assembly')
    parser.add_argument('--sample-id', required=True)
    parser.add_argument('--consensus', required=True, help='Consensus FASTA (.fa)')
    parser.add_argument('--coverage',  required=True, help='samtools coverage output (.txt)')
    parser.add_argument('--output',    required=True, help='Output TSV (sample_id, qc_flag)')
    args = parser.parse_args()

    ref_end, mean_depth_str = parse_coverage(args.coverage)
    num_bases, num_n        = parse_consensus(args.consensus)

    ref_len    = int(ref_end)
    called     = num_bases - num_n
    pct_genome = (called / ref_len * 100) if ref_len > 0 else 0.0
    mean_depth = float(mean_depth_str)

    if pct_genome < QC_MIN_COVERAGE:
        flag = f"FAIL: Percent genome < {int(QC_MIN_COVERAGE)}%"
    elif mean_depth < QC_MIN_DEPTH:
        flag = f"FAIL: Mean read depth < {int(QC_MIN_DEPTH)}x ({mean_depth:.1f}x)"
    else:
        flag = 'PASS'

    with open(args.output, 'w') as fh:
        fh.write('sample_id\tqc_flag\n')
        fh.write(f"{args.sample_id}\t{flag}\n")

    print(f"QC for {args.sample_id}: {flag}", file=sys.stderr)


if __name__ == '__main__':
    main()
