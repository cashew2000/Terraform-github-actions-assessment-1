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
              
              # Update system
              apt-get update -y

              # Install dependencies: Java and Git
              apt-get install -y openjdk-19-jdk git curl

              # Create app directory
              mkdir -p /home/ubuntu/app
              cd /home/ubuntu

              # Clone GitHub repo
              git clone https://github.com/techeazy-consulting/techeazy-devops.git app

              # Move into app folder
              cd /home/ubuntu/app

              # Check if any JAR file or run.sh exists, else run simple HTTP server
              if ls *.jar 1> /dev/null 2>&1; then
                JAR_FILE=$(ls *.jar | head -n 1)
                echo "Running JAR: $JAR_FILE" | tee -a /home/ubuntu/app_setup.log
                nohup java -jar $JAR_FILE > /home/ubuntu/app.log 2>&1 &
              elif [ -f "run.sh" ]; then
                echo "Running custom run.sh" | tee -a /home/ubuntu/app_setup.log
                chmod +x run.sh
                nohup ./run.sh > /home/ubuntu/app.log 2>&1 &
              else
                echo "No app start file found. Launching simple Python HTTP server." | tee -a /home/ubuntu/app_setup.log
                apt-get install -y python3
                nohup python3 -m http.server 80 > /home/ubuntu/app.log 2>&1 &
              fi

              # Wait and check if port 80 responds
              for i in {1..10}; do
                if curl -sSf http://localhost:80 >/dev/null 2>&1; then
                  echo "App is reachable on port 80" | tee -a /home/ubuntu/app_setup.log
                  break
                else
                  echo "Waiting for app to start... attempt $i" | tee -a /home/ubuntu/app_setup.log
                  sleep 10
                fi
              done

              echo "Setup complete" | tee -a /home/ubuntu/app_setup.log
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
