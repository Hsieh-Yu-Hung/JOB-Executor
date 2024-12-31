import os
import time
import argparse
import base64

# Default Constants
REGION = "asia-east1"
PROJECT_ID = "accuinbio-core"
CPU = 8             # 8 cores
MEMG = 32           # 32 GB RAM
TIME_LIMIT = 43200  # 12 hours
# Constants Job STATUS
STATUS_SUCCEEDED = "EXECUTION_SUCCEEDED"
STATUS_FAILED = "EXECUTION_FAILED"
STATUS_RUNNING = "EXECUTION_RUNNING"

# Option parser
parser = argparse.ArgumentParser(description="送 job 到 Cloud Run: 通用")
parser.add_argument("--cloud_image", required=True, help="Cloud Run image 的完整路徑")
parser.add_argument("--config_path", required=True, help="config 檔案的路徑。")
parser.add_argument("--script_path", required=True, help="script 檔案的路徑。")
parser.add_argument("--job_name", required=True, help="job 的名稱。")
parser.add_argument("--log_dir", required=False, default="logs", help="運行回報 logs 檔案的資料夾。")
parser.add_argument("--run_mode", required=False, default="cloud", choices=["local", "cloud"], help="job 的執行模式")
parser.add_argument("--project_id", required=False, default=PROJECT_ID, help=f"job 的 project id, default = {PROJECT_ID}")
parser.add_argument("--region", required=False, default=REGION, help=f"job 的 region, default = {REGION}")
parser.add_argument("--cpu", required=False, default=CPU, help=f"job 的 CPU 數量, default = {CPU}")
parser.add_argument("--memg", required=False, default=MEMG, help=f"job 的記憶體大小, default = {MEMG}GiB")
parser.add_argument("--timelimit", required=False, default=TIME_LIMIT, help=f"job 的時間限制, default = {TIME_LIMIT}s")
args = parser.parse_args()

# A function to monitor the job status
def monitor_job_status(job_name):
    command = (
        f"gcloud run jobs describe {job_name} "
        f"--format yaml --region {args.region} | grep 'completionStatus' | awk '{{print $2}}'"
    )
    status = os.popen(command).read()
    return status.strip() # Remove the newline character

# A function to keep monitoring the job status until it is completed or failed
def monitor_job(job_name, interval):

    # Count running time
    count = 0
    
    # Get the job status
    status = monitor_job_status(job_name)

    # Hint the user logs
    print(f" --> Job: {job_name} is running. Please check the gCloud Console for more details.")

    # Keep monitoring the job status
    while status == STATUS_RUNNING:
        status = monitor_job_status(job_name)
        time.sleep(interval)
        count += interval
        print(f" --> Job: {job_name} is running for {count} seconds. STATUS: {status}")
    
    # Download the output files if the job is completed successfully
    if status == STATUS_SUCCEEDED:
        print(f" --> Job: {job_name} completed successfully.")

    elif status == STATUS_FAILED:
        print(f" --> Job: {job_name} failed. status = <{status}>. Please check the logs.")
    else:
        print(f" --> Job: {job_name} is under Unknown status: <{status}>. Please check the logs.")

# A function to encode the content of a file to Base64
def encode_file_content(file_path):
    with open(file_path, 'r') as file:
        content = file.read()
        return base64.b64encode(content.encode()).decode()

# A function to execute the command on the cloud
def run_cloud_job():

    # Define the job name
    job_name = f"{args.job_name}"

    # 讀取 config_path 檔案的內容並進行 Base64 編碼
    encoded_config = encode_file_content(args.config_path)

    # 讀取 script_path 檔案的內容並進行 Base64 編碼
    encoded_script = encode_file_content(args.script_path)

    # Deploy the job
    deploy_commands = [
        "gcloud run jobs deploy",
        job_name,
        f"--image {args.cloud_image}",
        f"--region {args.region}",
        f"--cpu {args.cpu}",
        f"--memory {args.memg}Gi",
        f"--task-timeout {args.timelimit}s",
        f"--max-retries 0",
        f"--set-env-vars=CONFIGS='{encoded_config}',SH_SCRIPT='{encoded_script}'"
    ]
    os.system(" ".join(deploy_commands))

    # Execute the job
    execute_command = (
        f"gcloud run jobs execute {job_name} --region {args.region}"
    )
    os.system(execute_command)

    return job_name

# A function to execute the command on the local machine
def run_local_job():

    # 讀取 config_path 檔案的內容並進行 Base64 編碼
    encoded_config = encode_file_content(args.config_path)

    # 讀取 script_path 檔案的內容並進行 Base64 編碼
    encoded_script = encode_file_content(args.script_path)

    # Run
    command = f"docker run --privileged --rm --name {args.job_name} -e CONFIGS='{encoded_config}' -e SH_SCRIPT='{encoded_script}' {args.cloud_image}"
    os.system(command)

# A function to get logs and delete finished job
def get_logs_and_delete_job(job_name):

    # 讀取 log
    os.system(f"""gcloud logging read 'resource.type = "cloud_run_job" resource.labels.job_name = "{job_name}" resource.labels.location = "{args.region}" labels."run.googleapis.com/task_index" = "0" severity>=DEFAULT' | grep 'textPayload' > {os.path.join("logs", f"{job_name}.logs")}""")
    
    # 刪除 job
    os.system(f"gcloud run jobs delete {job_name} --region {args.region} --quiet")
    
    # 讀取 log 並判斷 job 是否成功或失敗
    with open(os.path.join("logs", f"{job_name}.logs"), "r") as file:
        logs = file.read()
        if "失敗" in logs:
            return False
        else:
            return True

if __name__ == "__main__":
    if args.run_mode == "cloud":
        job_name = run_cloud_job()
        monitor_job(job_name, 10)
        finish_success = get_logs_and_delete_job(job_name)
        if finish_success:
            exit(0)
        else:
            exit(1)
    elif args.run_mode == "local":
        run_local_job()