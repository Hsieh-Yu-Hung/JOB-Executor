# Send Pipeline 使用說明

應用 `sent_jobs.py` 執行一連串工作, 範例為 `sent_jobs_General.sh`, 另外有 Cloud run 版本, 請參考 <連結>

這個 pipeline 是做 STAR-Fusion, 也可以應用來組合其他 pipeline

### 使用方式

1. 請確保 main_scripts 底下的 shell script 已經完成獨立測試, 可以在指定 image 運行
2. 在腳本 `sent_jobs_General.sh`中設定 `'local'` 或者 `'cloud' `模式
3. 執行腳本並提供 sampleID

   ```
   sent_jobs_General.sh <SAMPLE ID>
   ```

* 若是 'cloud' 模式則會依序送出 STAR-Fusion 幾個步驟的 Cloud Run Job 並等待結果, log 和 config 會上傳至 GCS
* 若是 'local' 模式則會使用 docker 在指定 image 的 container 中執行所提供的 shell scripts, log 和 config 會存到本地

### 運作方式
1. 由腳本生成 config 檔, 並將 <SAMPLE ID> 替換至設定檔內
2. 執行指令`python sent_jobs.py`並檢查其執行結果
3. 在腳本內執行多個步驟, 每步執行由以下函式監督
＊ 每一個步驟獨立測試時必須確保他意外終止後會返回狀態碼 1  

```bash
# 定義一個函數來執行指令並檢查其執行結果
function execute_and_check() {
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        echo "Error: Command '$*' failed with status $status"
        exit $status
    fi
}
```

### 範例檔案

* General Config: 含特殊字串供替換 `<SAMPLE ID>`使用, 範例：configs/General_configs/JOB_Preporcess.conf, 替換字串為 __ SAMPLE_ID __

```json
{
    "inputs": [
        {
            "gcs_bucket": "accuinbio-core-dev",
            "gcs_path": "STAR-FUSION/raw_fastq/__SAMPLE_ID__*",
            "local_path": "./",
            "file_type": "file",
            "transfer_method": "command_line"
        }
    ],
    "outputs": [
        {
            "gcs_bucket": "accuinbio-core-dev",
            "gcs_path": "STAR-FUSION/Fusion_Preprocessed/__SAMPLE_ID__-preprocess",
            "local_path": "__SAMPLE_ID__-preprocess",
            "file_type": "folder",
            "transfer_method": "command_line"
        },
        {
            "gcs_bucket": "accuinbio-core-dev",
            "gcs_path": "STAR-FUSION/SF_Reports/__SAMPLE_ID__-reports/cutadapt_report.json",
            "local_path": "__SAMPLE_ID__-preprocess/cutadapt_report.json",
            "file_type": "file",
            "transfer_method": "python"
        },
        {
            "gcs_bucket": "accuinbio-core-dev",
            "gcs_path": "STAR-FUSION/SF_Reports/__SAMPLE_ID__-reports",
            "local_path": "__SAMPLE_ID__-preprocess/*.xlsx",
            "file_type": "file",
            "transfer_method": "command_line"
        }
    ],
    "cli_params": [
        "__SAMPLE_ID___R1_001.fastq.gz",
        "__SAMPLE_ID___R2_001.fastq.gz",
        "__SAMPLE_ID__-preprocess"
    ]
}
```

* Main script：實際上執行分析的 shell script. 範例：main_scripts/step1-PreprocessFQ.sh

```bash
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
```

* Logs：由 Cloud Run Job 產生的紀錄檔, 可以用來 debug, 範例：logs/preprocess-test.logs

```plaintext
textPayload: Container called exit(0).
textPayload: ' --> 分析流程完成！'
textPayload: ' --> 上傳到：STAR-FUSION/SF_Reports/RNA-CLH74_S12_L001-reports '
textPayload: ' --> 本地檔案：RNA-CLH74_S12_L001-preprocess/*.xlsx '
textPayload: ' --> [上傳檔案] '
textPayload: ' --> 上傳到：STAR-FUSION/SF_Reports/RNA-CLH74_S12_L001-reports/cutadapt_report.json '
textPayload: ' --> 本地檔案：RNA-CLH74_S12_L001-preprocess/cutadapt_report.json '
textPayload: ' --> [上傳檔案] '
textPayload: ' --> 上傳到：STAR-FUSION/Fusion_Preprocessed/RNA-CLH74_S12_L001-preprocess '
textPayload: ' --> 本地資料夾：RNA-CLH74_S12_L001-preprocess '
textPayload: ' --> [上傳資料夾] '
textPayload: ' --> 上傳結果...'
textPayload: ' --> 執行 CLI 指令...'
textPayload: ' --> 解析 CLI 腳本...'
textPayload: ' --> 下載到：./ '
textPayload: ' --> 遠端檔案：STAR-FUSION/raw_fastq/RNA-CLH74_S12_L001* '
textPayload: ' --> [下載檔案] '
textPayload: ' --> 下載資料...1 個'
textPayload: ' --> 開始跑分析流程...'
textPayload: 'Operation completed over 2 objects/41.9 KiB.                                     '
textPayload: '/ [2 files][ 41.9 KiB/ 41.9 KiB]                                                '
textPayload: '/ [1 files][  9.9 KiB/ 41.9 KiB]                                                '
textPayload: Copying file://RNA-CLH74_S12_L001-preprocess/group_pair_counts_primer_preprocess.xlsx
textPayload: '/ [1 files][  9.9 KiB/  9.9 KiB]                                                '
textPayload: '/ [0 files][    0.0 B/  9.9 KiB]                                                '
textPayload: Copying file://RNA-CLH74_S12_L001-preprocess/group_pair_counts_gene_preprocess.xlsx
textPayload: 'Operation completed over 14 objects/126.3 MiB.                                   '
textPayload: '\ [14/14 files][126.3 MiB/126.3 MiB] 100% Done                                  '
textPayload: '\ [13/14 files][112.8 MiB/126.3 MiB]  89% Done                                  '
textPayload: \
textPayload: '- [12/14 files][ 72.0 MiB/126.3 MiB]  57% Done                                  '
textPayload: '-'
textPayload: '/ [11/14 files][ 33.9 MiB/126.3 MiB]  26% Done                                  '
textPayload: '/ [10/14 files][ 25.1 MiB/126.3 MiB]  19% Done                                  '
textPayload: '/ [9/14 files][  8.9 MiB/126.3 MiB]   7% Done                                   '
textPayload: '/ [8/14 files][  8.1 MiB/126.3 MiB]   6% Done                                   '
textPayload: '/ [7/14 files][  3.7 MiB/126.3 MiB]   2% Done                                   '
textPayload: '/ [6/14 files][  3.7 MiB/126.3 MiB]   2% Done                                   '
textPayload: '/ [5/14 files][  1.7 MiB/126.3 MiB]   1% Done                                   '
textPayload: '/ [4/14 files][  1.7 MiB/126.3 MiB]   1% Done                                   '
textPayload: '/ [3/14 files][  1.7 MiB/126.3 MiB]   1% Done                                   '
textPayload: '/ [2/14 files][  1.7 MiB/126.3 MiB]   1% Done                                   '
textPayload: '/ [1/14 files][  1.3 MiB/126.3 MiB]   1% Done                                   '
textPayload: '/ [0/14 files][630.7 KiB/126.3 MiB]   0% Done                                   '
textPayload: Copying file://RNA-CLH74_S12_L001-preprocess/trimmed_fq/primer_trimmed_R1_val_1.fq.gz
textPayload: '/ [0/14 files][598.7 KiB/126.3 MiB]   0% Done                                   '
textPayload: Copying file://RNA-CLH74_S12_L001-preprocess/trimmed_fq/primer_trimmed_R1.fastq.gz
textPayload: '/ [0/14 files][    0.0 B/126.3 MiB]   0% Done                                   '
textPayload: Copying file://RNA-CLH74_S12_L001-preprocess/trimmed_fq/primer_trimmed_R2_val_2.fq.gz
textPayload: '/ [0/14 files][    0.0 B/126.3 MiB]   0% Done                                   '
textPayload: Copying file://RNA-CLH74_S12_L001-preprocess/trimmed_fq/primer_trimmed_R2.fastq.gz
textPayload: '/ [0/14 files][    0.0 B/126.3 MiB]   0% Done                                   '
......
......
```
