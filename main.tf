provider "aws" {
  region = var.aws_region
}

# ✅ Get the latest Ubuntu 22.04 LTS AMI for your region
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's AWS account ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# ✅ Security Group: allow SSH and HTTP
resource "aws_security_group" "devops_sg" {
  name_prefix = "devops-sg-"
  description = "Allow SSH and HTTP"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ✅ EC2 Instance (Ubuntu)
resource "aws_instance" "devops_ec2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.devops_sg.id]

#Updating user_data to clone and run app at port 80
  user_data = <<-EOF
              #!/bin/bash
              set -xe

              LOG=/home/ubuntu/app_setup.log
              echo "user_data started at $(date)" > ${LOG}

              # Update and install dependencies
              apt-get update -y
              apt-get install -y openjdk-19-jdk git curl unzip maven

              echo "Java version:" >> ${LOG}
              java -version >> ${LOG} 2>&1 || true

              cd /home/ubuntu
              # Clone (or pull if already present)
              if [ -d "/home/ubuntu/app" ]; then
                echo "app exists; pulling latest" >> ${LOG}
                cd /home/ubuntu/app && git pull >> ${LOG} 2>&1 || true
              else
                git clone https://github.com/techeazy-consulting/techeazy-devops.git app >> ${LOG} 2>&1 || { echo "git clone failed" >> ${LOG}; }
                cd /home/ubuntu/app || { echo "app dir missing" >> ${LOG}; }
              fi

              echo "Listing app files:" >> ${LOG}
              ls -la >> ${LOG}

              STARTED=0

              # If Maven project (pom.xml), build & run
              if [ -f "pom.xml" ]; then
                echo "Detected pom.xml - using Maven build" >> ${LOG}
                mvn -DskipTests package -T1C >> ${LOG} 2>&1 || echo "mvn build failed" >> ${LOG}
                JAR=$(ls target/*.jar 2>/dev/null | grep -v "original" | head -n1 || true)
                if [ -n "$JAR" ]; then
                  echo "Found jar: $JAR" >> ${LOG}
                  nohup java -jar "$JAR" --server.port=80 > /home/ubuntu/app.log 2>&1 &
                  STARTED=1
                fi
              fi

              # If Gradle wrapper exists
              if [ $STARTED -eq 0 ] && [ -f "gradlew" ]; then
                echo "Detected gradlew - building" >> ${LOG}
                chmod +x ./gradlew
                ./gradlew bootJar -x test >> ${LOG} 2>&1 || echo "gradle build failed" >> ${LOG}
                JAR=$(ls build/libs/*.jar 2>/dev/null | head -n1 || true)
                if [ -n "$JAR" ]; then
                  echo "Found jar: $JAR" >> ${LOG}
                  nohup java -jar "$JAR" --server.port=80 > /home/ubuntu/app.log 2>&1 &
                  STARTED=1
                fi
              fi

              # If a runnable jar exists at repo root or other usual places
              if [ $STARTED -eq 0 ]; then
                JARROOT=$(find . -maxdepth 3 -type f -name "*.jar" -print | grep -v "original" | head -n1 || true)
                if [ -n "$JARROOT" ]; then
                  echo "Found jar at $JARROOT" >> ${LOG}
                  nohup java -jar "$JARROOT" --server.port=80 > /home/ubuntu/app.log 2>&1 &
                  STARTED=1
                fi
              fi

              # If there's a custom run.sh
              if [ $STARTED -eq 0 ] && [ -f "run.sh" ]; then
                echo "Found run.sh - starting it" >> ${LOG}
                chmod +x run.sh
                nohup ./run.sh > /home/ubuntu/app.log 2>&1 &
                STARTED=1
              fi

              # Fallback: serve directory via python simple server on port 80
              if [ $STARTED -eq 0 ]; then
                echo "No app start file found. Launching Python HTTP server (fallback)" >> ${LOG}
                apt-get install -y python3
                nohup python3 -m http.server 80 > /home/ubuntu/app.log 2>&1 &
              fi

              # Wait & health-check loop for localhost:80
              echo "Waiting for app to respond on port 80" >> ${LOG}
              for i in {1..30}; do
                if curl -sSf http://localhost:80 >/dev/null 2>&1; then
                  echo "App reachable on port 80 (attempt $i)" >> ${LOG}
                  break
                else
                  echo "Attempt $i: not yet responding" >> ${LOG}
                  sleep 5
                fi
              done

              # Save last lines of app log to main log
              echo "Last 50 lines of app.log:" >> ${LOG}
              tail -n 50 /home/ubuntu/app.log >> ${LOG} 2>&1 || true

              # Auto-shutdown if configured
              AUTOSTOP=${auto_stop_minutes}
              if [ "${AUTOSTOP}" != "0" ] && [ "${AUTOSTOP}" != "" ]; then
                echo "Scheduling shutdown in ${AUTOSTOP} minutes" >> ${LOG}
                /sbin/shutdown -h +${AUTOSTOP} "Auto shutdown scheduled by provisioning script after ${AUTOSTOP} minutes"
              else
                echo "Auto shutdown disabled (auto_stop_minutes=${AUTOSTOP})" >> ${LOG}
              fi

              echo "user_data finished at $(date)" >> ${LOG}
              EOF
  tags = {
    Name  = "devops-${var.stage}-instance"
    Stage = var.stage
  }
}

# ✅ Outputs
output "public_ip" {
  value = aws_instance.devops_ec2.public_ip
}

output "public_dns" {
  value = aws_instance.devops_ec2.public_dns
}
