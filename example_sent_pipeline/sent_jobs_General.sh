#!/bin/bash

sample_id=$1
mode="local"
# 將 sample_id 轉換成小寫並將底線換成連字號，儲存到 jid
jid=$(echo "$sample_id" | tr '[:upper:]' '[:lower:]' | sed 's/_/-/g')

# 檢查 sample_id 是否提供
if [ -z "$sample_id" ]; then
    echo "Please provide a sample ID!"
    exit 1
fi

# 檢查 configs/$sample_id 是否存在，不存在則建立
if [ ! -d "configs/$sample_id" ]; then
    mkdir -p "configs/$sample_id"
fi

# 建立 configs/$sample_id 的 job 設定檔
sed "s/__SAMPLE_ID__/$sample_id/g" configs/General_configs/JOB_Preporcess.conf > configs/$sample_id/JOB_Preporcess_$sample_id.conf
sed "s/__SAMPLE_ID__/$sample_id/g" configs/General_configs/JOB_STAR-align.conf > configs/$sample_id/JOB_STAR-align_$sample_id.conf
sed "s/__SAMPLE_ID__/$sample_id/g" configs/General_configs/JOB_STAR-fusion.conf > configs/$sample_id/JOB_STAR-fusion_$sample_id.conf
sed "s/__SAMPLE_ID__/$sample_id/g" configs/General_configs/JOB_SF_Sum_Report.conf > configs/$sample_id/JOB_SF_Sum_Report_$sample_id.conf

# 定義一個函數來執行指令並檢查其執行結果
function execute_and_check() {
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        echo "Error: Command '$*' failed with status $status"
        exit $status
    fi
}

# 執行 Preprocess 的 job
execute_and_check python sent_jobs.py \
    --cloud_image "asia-east1-docker.pkg.dev/accuinbio-core/cloud-run-source-deploy/star-fusion-preprocess:latest" \
    --config_path "configs/$sample_id/JOB_Preporcess_$sample_id.conf" \
    --script_path "main_scripts/step1-PreprocessFQ.sh" \
    --job_name "preprocess-$jid" \
    --run_mode $mode

# 執行 STAR-align 的 job
execute_and_check python sent_jobs.py \
    --cloud_image "asia-east1-docker.pkg.dev/accuinbio-core/cloud-run-source-deploy/star_fusion_run:latest" \
    --config_path "configs/$sample_id/JOB_STAR-align_$sample_id.conf" \
    --script_path "main_scripts/step2-STAR_align.sh" \
    --job_name "star-align-$jid" \
    --run_mode $mode

# 執行 STAR-fusion 的 job
execute_and_check python sent_jobs.py \
    --cloud_image "asia-east1-docker.pkg.dev/accuinbio-core/cloud-run-source-deploy/star_fusion_run:latest" \
    --config_path "configs/$sample_id/JOB_STAR-fusion_$sample_id.conf" \
    --script_path "main_scripts/step3-STAR_fusion_Inspect.sh" \
    --job_name "star-fusion-$jid" \
    --run_mode $mode

# 執行 STAR-fusion-report 的 job
execute_and_check python sent_jobs.py \
    --cloud_image "asia-east1-docker.pkg.dev/accuinbio-core/cloud-run-source-deploy/sf-sum-report:latest" \
    --config_path "configs/$sample_id/JOB_SF_Sum_Report_$sample_id.conf" \
    --script_path "main_scripts/step4-SF_Summary_Reports.sh" \
    --job_name "sf-summary-$jid" \
    --run_mode $mode