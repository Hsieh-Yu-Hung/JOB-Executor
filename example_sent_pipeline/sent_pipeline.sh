#!/bin/bash

# 參數設定
SAMPLE_ID=$1

# 將 sample_id 轉換成小寫並將底線換成連字號，儲存到 jid
JOB_NAME=$(echo sfp_"$SAMPLE_ID" | tr '[:upper:]' '[:lower:]' | sed 's/_/-/g')

# 其他參數
CLOUD_IMAGE=asia-east1-docker.pkg.dev/accuinbio-core/cloud-run-source-deploy/star-fusion-pipeline:latest
REGION=asia-east1
CPU=8
MEMG=32
TIMELIMIT=86400

# 部署工作
gcloud run jobs deploy "$JOB_NAME" \
    --image "$CLOUD_IMAGE" \
    --region "$REGION" \
    --cpu "$CPU" \
    --memory "${MEMG}Gi" \
    --task-timeout "${TIMELIMIT}s" \
    --max-retries 0 \
    --set-env-vars="SAMPLE_ID=${SAMPLE_ID}"

# 執行工作
gcloud run jobs execute "$JOB_NAME" --region "$REGION"