#!/bin/bash

fq_1=$1
fq_2=$2
genome=$3
outdir=$4
bucket_name=$5

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
check_file_exists $fq_1
check_file_exists $fq_2

# Run STAR
/usr/local/bin/STAR \
    --genomeDir /app/db/$genome \
    --outReadsUnmapped None \
    --chimSegmentMin 12 \
    --chimJunctionOverhangMin 8 \
    --chimOutJunctionFormat 1 \
    --alignSJDBoverhangMin 10 \
    --alignMatesGapMax 100000 \
    --alignIntronMax 100000 \
    --alignSJstitchMismatchNmax 5 -1 5 5 \
    --runThreadN 8 \
    --outSAMstrandField intronMotif \
    --outSAMunmapped Within \
    --alignInsertionFlush Right \
    --alignSplicedMateMapLminOverLmate 0 \
    --alignSplicedMateMapLmin 30 \
    --outSAMtype BAM Unsorted \
    --readFilesIn /app/$fq_1 /app/$fq_2 \
    --outSAMattrRGline ID:GRPundef \
    --chimMultimapScoreRange 3 \
    --chimScoreJunctionNonGTAG -4 \
    --chimMultimapNmax 20 \
    --chimOutType Junctions WithinBAM \
    --chimNonchimScoreDropMin 10 \
    --peOverlapNbasesMin 12 \
    --peOverlapMMp 0.1 \
    --genomeLoad NoSharedMemory \
    --twopassMode None \
    --readFilesCommand "gunzip -c" \
    --quantMode GeneCounts \
    --outFileNamePrefix /app/$outdir/STAR_

# Run feature count
task_scripts/featureCount.sh /app/$outdir/STAR_Aligned.out.bam ref_annot.gtf /app/$outdir/Exon_Quant

# Compute Exon span
python task_scripts/count_exon_span.py -b /app/$outdir/Exon_Quant.junction.bed -g ref_annot.gtf

# Annotate featurecount result
python task_scripts/AnnotateResult.py \
 -b /app/$outdir/Exon_Quant.junction_ExonSpan.bed \
 -a RNA-Panel_GeneList_ExJ_2024_Nov.bed \
 -o /app/$outdir/Annotated_featurecount.xlsx
