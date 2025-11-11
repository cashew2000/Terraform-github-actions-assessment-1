#!/bin/bash
set -xe

LOG=/home/ubuntu/app_setup.log
echo "user_data started at $(date)" > $LOG

# Update and install dependencies
apt-get update -y
apt-get install -y openjdk-19-jdk git curl unzip maven python3

echo "Java version:" >> $LOG
java -version >> $LOG 2>&1 || true

cd /home/ubuntu

# Clone or update repo
if [ -d "/home/ubuntu/app" ]; then
  echo "Existing repo found, pulling latest" >> $LOG
  cd /home/ubuntu/app && git pull >> $LOG 2>&1
else
  git clone https://github.com/techeazy-consulting/techeazy-devops.git app >> $LOG 2>&1
  cd /home/ubuntu/app || { echo "Failed to enter app directory" >> $LOG; exit 1; }
fi

# Try to build/run Spring Boot app
STARTED=0
if [ -f "pom.xml" ]; then
  echo "Detected pom.xml – using Maven build" >> $LOG
  mvn -DskipTests package >> $LOG 2>&1
  JAR=$(find target -maxdepth 1 -type f -name "*.jar" ! -name "original*" | head -n1 || true)
  if [ -n "$JAR" ]; then
    nohup java -jar "$JAR" --server.port=80 > /home/ubuntu/app.log 2>&1 &
    STARTED=1
  fi
fi


# Fallback simple web server
if [ $STARTED -eq 0 ]; then
  echo "No runnable jar found; starting Python HTTP server on port 80" >> $LOG
  nohup python3 -m http.server 80 > /home/ubuntu/app.log 2>&1 &
fi

# Health check loop (safe syntax)
echo "Waiting for app to respond on port 80" >> $LOG
for ((i=1;i<=30;i++)); do
  if curl -sSf http://localhost:80 >/dev/null 2>&1; then
    echo "App reachable on port 80 (attempt $i)" >> $LOG
    break
  else
    echo "Attempt $i: not yet responding" >> $LOG
    sleep 5
  fi
done

# Auto-shutdown
AUTOSTOP=${auto_stop_minutes}
if [ "$AUTOSTOP" != "0" ] && [ "$AUTOSTOP" != "" ]; then
  echo "Scheduling shutdown in $AUTOSTOP minutes" >> $LOG
  /sbin/shutdown -h +$AUTOSTOP "Auto shutdown after $AUTOSTOP minutes"
else
  echo "Auto shutdown disabled" >> $LOG
fi

echo "user_data finished at $(date)" >> $LOG
