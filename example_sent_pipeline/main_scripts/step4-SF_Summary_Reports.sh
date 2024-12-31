#!/bin/bash

cutadapt_report=$1
star_log=$2
starfusion_anno=$3
preprocess_report_gene=$4
starfusion_report_gene=$5
preprocess_report_primer=$6
starfusion_report_primer=$7
annotated_feature_count=$8
output_file=$9

# A function to check if the file exists
check_file_exists() {
    if [ ! -f $1 ]; then
        echo "$1 不存在"
        exit 1
    fi
}

check_file_exists $cutadapt_report
check_file_exists $star_log
check_file_exists $starfusion_anno
check_file_exists $preprocess_report_gene
check_file_exists $starfusion_report_gene
check_file_exists $preprocess_report_primer
check_file_exists $starfusion_report_primer
check_file_exists $annotated_feature_count
python task_scripts/starfusion_report_summart.py \
    --cutadapt_report $cutadapt_report \
    --star_log $star_log \
    --starfusion_anno $starfusion_anno \
    --preprocess_report_gene $preprocess_report_gene \
    --starfusion_report_gene $starfusion_report_gene \
    --preprocess_report_primer $preprocess_report_primer \
    --starfusion_report_primer $starfusion_report_primer \
    --annotated_feature_count $annotated_feature_count \
    --output_file $output_file