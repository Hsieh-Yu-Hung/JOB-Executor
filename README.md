# JOB-Executor
這個專案是應用 GCP_Manager 來自動化送 cloud run 工作流程。可以指定一個已經完成測試的映像檔, 當下提供執行腳本和工作設定, 去在 dev-1 或是 clould run 執行工作。使用 `CRL_Manager` 的作業流程, 請依照工作設定檔規範完成工作設定且在執行時提供每一個工作相應的設定, 就能自動完成 "下載至 Container" -> "執行 CLI" -> "上傳回 GCS" 這三個步驟。

## 使用方法
下載 `sent_jobs.py` 並指定 `cloud` 或 `local` 模式執行即可, shell script 是由外部提供, 給予了比較大的彈性, 但是請先確保所使用的映像是能夠執行該 shell script! `cloud` 模式會送一個 job 到 cloud run 上面跑; `local` 模式會在 dev-1 (或是本地)上面跑, 都會把檔案上傳至 GCS。
```bash
python sent_jobs.py \
  --cloud_image <映像檔> \
  --config_path <工作設定檔> \
  --script_path <shell scirpt> \
  --job_name <工作名稱(gcloud只接受小寫英文字！)> \
  --run_mode $mode
```
## 工作設定檔規範
- 格式：JSON 檔案
- 項目：

   1. inputs(字典列表) - 輸入要從 GCS 下載到容器中的檔案
   2. outputs(字典列表) - 輸入要從容器上傳回 GCS 的檔案
   3. cli_params(字串列表) - 依照順序輸入所提供 shell script 的參數
  
- 使用 `command_line` 傳輸模式可以在檔名加上 *
- 可以指定多個上傳和下載, 新增一個字典到列表中即可
- 範例
```json
{
    "inputs": [
        {
            "gcs_bucket": "GCS_BUCKET",
            "gcs_path": "GCS_PATH",
            "local_path": "LOCAL_PATH",
            "file_type": "file or folder",
            "transfer_method": "command_line or python"
        }
    ],
    "outputs": [
        {
            "gcs_bucket": "GCS_BUCKET",
            "gcs_path": "GCS_PATH",
            "local_path": "LOCAL_PATH",
            "file_type": "folder or file",
            "transfer_method": "command_line or python"
        }
    ],
    "cli_params": [
        "CLI_PARAM_1",
        "CLI_PARAM_2",
        "CLI_PARAM_3",
        "看有幾個參數就放幾個",
        "是位置參數！請依照順序填寫"
    ]
}
```
