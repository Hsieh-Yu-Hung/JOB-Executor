#!/bin/bash

# parameters
input_R1=$1
input_R2=$2
output_dir=$3

# make output directory
if [ ! -d ${output_dir} ]; then
    mkdir -p ${output_dir}
    mkdir -p tmp/fastqc
    mkdir -p ${output_dir}/trimmed_fq
fi

# Trim primers
cutadapt \
 -j 8 \
 -g 'file:primer_sets/RNA-for-primer.fa' \
 -G 'file:primer_sets/RNA-rev-primer.fa' \
 --rename '{header}_primer:{adapter_name}_seq:{match_sequence}' \
 --action retain \
 -m 60 -e 0 -q 30,30 \
 --overlap 12 \
 --discard-untrimmed \
 --nextseq-trim=30 \
 --no-indels \
 --poly-a \
 --json='tmp/cutadapt_report.json' \
 --info-file='tmp/cutadapt_info.txt' \
 -o ${output_dir}/trimmed_fq/primer_trimmed_R1.fastq.gz \
 -p ${output_dir}/trimmed_fq/primer_trimmed_R2.fastq.gz \
 $input_R1 \
 $input_R2

# move cutadapt report and info to output directory
mv tmp/cutadapt_report.json ${output_dir}/cutadapt_report.json
mv tmp/cutadapt_info.txt ${output_dir}/cutadapt_info.txt

# Remove adaptors
trim_galore \
 --illumina \
 --paired \
 --gzip \
 --fastqc \
 --fastqc_args '--outdir tmp/fastqc' \
 --output_dir ${output_dir}/trimmed_fq \
 --length 60 \
 -j 8 \
 ${output_dir}/trimmed_fq/primer_trimmed_R1.fastq.gz \
 ${output_dir}/trimmed_fq/primer_trimmed_R2.fastq.gz

mv tmp/fastqc ${output_dir}/fastqc
rm -d tmp

# Generate read group:primer
python task_scripts/read_groups_QC.py \
 -r1 ${output_dir}/trimmed_fq/primer_trimmed_R1_val_1.fq.gz \
 -r2 ${output_dir}/trimmed_fq/primer_trimmed_R2_val_2.fq.gz \
 -o ${output_dir}/group_pair_counts_primer_preprocess.xlsx \
 -g 0

# Generate read group:gene
python task_scripts/read_groups_QC.py \
 -r1 ${output_dir}/trimmed_fq/primer_trimmed_R1_val_1.fq.gz \
 -r2 ${output_dir}/trimmed_fq/primer_trimmed_R2_val_2.fq.gz \
 -o ${output_dir}/group_pair_counts_gene_preprocess.xlsx \
 -g 2