#!/bin/bash
set -e

LOG=/home/ubuntu/app_setup.log
APP_LOG=/home/ubuntu/app.log

echo "[INFO] user_data started at $(date)" | tee -a $LOG

# ----------------------------
# System update & dependencies
# ----------------------------
apt-get update -y >> $LOG 2>&1
apt-get install -y openjdk-21-jdk maven git awscli curl >> $LOG 2>&1

java -version >> $LOG 2>&1
mvn -version >> $LOG 2>&1
aws --version >> $LOG 2>&1

# ----------------------------
# Variables
# ----------------------------
STAGE="${stage}"
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
BUCKET_NAME="${s3_bucket_name}"

S3_PATH="s3://$${BUCKET_NAME}/logs/$${STAGE}/$${INSTANCE_ID}"


# ----------------------------
# Clone / update repo
# ----------------------------
cd /home/ubuntu

if [ ! -d app ]; then
  git clone https://github.com/<YOUR_GITHUB_USERNAME>/<YOUR_REPO>.git app >> $LOG 2>&1
else
  cd app && git pull >> $LOG 2>&1
fi

cd /home/ubuntu/app

# ----------------------------
# Build and run application
# ----------------------------
mvn clean package >> $LOG 2>&1

nohup java -jar target/*.jar --server.port=80 > $APP_LOG 2>&1 &

# ----------------------------
# Health check
# ----------------------------
echo "[INFO] Waiting for app on port 80" | tee -a $LOG
for i in {1..30}; do
  if curl -s http://localhost:80 >/dev/null; then
    echo "[INFO] App is running" | tee -a $LOG
    break
  fi
  sleep 5
done

# ----------------------------
# Upload logs to S3
# ----------------------------
echo "[INFO] Uploading logs to S3" | tee -a $LOG

aws s3 cp $LOG     ${S3_PATH}/app_setup.log >> $LOG 2>&1
aws s3 cp $APP_LOG ${S3_PATH}/app.log       >> $LOG 2>&1

# ----------------------------
# Auto shutdown (if enabled)
# ----------------------------
if [ "${auto_stop_minutes}" != "0" ]; then
  echo "[INFO] Scheduling shutdown in ${auto_stop_minutes} minutes" | tee -a $LOG

  # Upload logs again just before shutdown
  (
    sleep $((${auto_stop_minutes} * 60 - 30))
    aws s3 cp $LOG     ${S3_PATH}/app_setup.log >> $LOG 2>&1
    aws s3 cp $APP_LOG ${S3_PATH}/app.log       >> $LOG 2>&1
  ) &

  shutdown -h +${auto_stop_minutes}
fi

echo "[INFO] user_data finished at $(date)" | tee -a $LOG
