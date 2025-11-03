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

  # 👇 User data script runs at startup
  user_data = <<-EOF
              #!/bin/bash
              set -xe
              
              # Update system and install Java (OpenJDK 19)
              apt-get update -y
              apt-get install -y openjdk-19-jdk

              # Verify Java installation
              java -version > /home/ubuntu/java_status.txt 2>&1
              echo "Java installation complete" >> /home/ubuntu/java_status.txt
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
