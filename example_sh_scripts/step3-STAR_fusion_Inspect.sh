#!/bin/bash

sj_file=$1
fq_1=$2
fq_2=$3
genome=$4
outdir=$5
bucket_name=$6

# mount GCS to local
gcsfuse --implicit-dirs --log-severity=ERROR $bucket_name /app/db &
sleep 5

# A function to check if the file exists
check_file_exists() {
    if [ ! -f $1 ]; then
        echo "$1 不存在"
        exit 1
    fi
}

# 檢查輸入檔案是否存在
check_file_exists $sj_file

# Run STAR-Fusion and log output to a file
STAR-Fusion \
    --CPU 8 \
    --left_fq /app/$fq_1 \
    --right_fq /app/$fq_2 \
    --genome_lib_dir /app/db/$genome \
    -J /app/$sj_file \
    --examine_coding_effect \
    --FusionInspector inspect \
    --denovo_reconstruct \
    --output_dir /app/$outdir

# annotate fusion predictions
python task_scripts/annotate_fuse_exon.py \
    --fusion_pred /app/$outdir/star-fusion.fusion_predictions.abridged.tsv \
    --gtf /app/db/$genome/ref_annot.gtf \
    --output /app/$outdir/star-fusion_predictions.annotated.xlsx

# annotate primer groups
python task_scripts/read_groups_QC.py \
    -r1 /app/$outdir/star-fusion.fusion_evidence_reads_1.fq \
    -r2 /app/$outdir/star-fusion.fusion_evidence_reads_2.fq \
    -o /app/$outdir/group_pair_counts_primer_starfusion.xlsx \
    -g 0

# annotate gene groups
python task_scripts/read_groups_QC.py \
    -r1 /app/$outdir/star-fusion.fusion_evidence_reads_1.fq \
    -r2 /app/$outdir/star-fusion.fusion_evidence_reads_2.fq \
    -o /app/$outdir/group_pair_counts_gene_starfusion.xlsx \
    -g 2