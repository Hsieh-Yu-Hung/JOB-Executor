#!/bin/bash

# 使用者提供的參數
mode=$1

# 映像檔 (請用已經測試好上傳發布的)
image="asia-east1-docker.pkg.dev/accuinbio-core/cloud-run-source-deploy/star-fusion-preprocess:latest"

# 定義一個函數來執行指令並檢查其執行結果
function execute_and_check() {
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        echo "Error: Command '$*' failed with status $status"
        exit $status
    fi
}

# 執行範例的 job
execute_and_check python sent_jobs.py \
    --cloud_image $image \
    --config_path "example_configs/example_JOB_Preporcess.conf" \
    --script_path "example_sh_scripts/step1-PreprocessFQ.sh" \
    --job_name "sf-preprocess" \
    --run_mode $mode

# ... 可以再執行其他 job, 可以直接寫一套 pipeline 的 script ...
# execute_and_check python sent_jobs.py \
#     --cloud_image OTHER_IMAGE \
#     --config_path OTHER_CONFIG \
#     --script_path OTHER_SCRIPT \
#     --job_name OTHER_JOB_NAME \
#     --run_mode $mode