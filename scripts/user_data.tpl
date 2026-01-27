#!/bin/bash
set -e

LOG=/home/ubuntu/bootstrap.log

echo "[INFO] Bootstrap started at $(date)" | tee -a $LOG

# Update system
apt-get update -y >> $LOG 2>&1

# Install dependencies
apt-get install -y \
  openjdk-21-jdk \
  maven \
  git \
  awscli \
  curl >> $LOG 2>&1

# Create app directory
mkdir -p /home/ubuntu/app
chown -R ubuntu:ubuntu /home/ubuntu/app

echo "[INFO] Bootstrap completed at $(date)" | tee -a $LOG
