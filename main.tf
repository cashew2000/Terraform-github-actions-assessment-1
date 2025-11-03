provider "aws" {
  region = var.aws_region
}

# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Security Group
resource "aws_security_group" "devops_sg" {
  name_prefix = "devops-sg-"
  description = "Allow SSH and HTTP access"

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

# EC2 Instance
resource "aws_instance" "devops_ec2" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.devops_sg.id]

 # 👇 Add this section
  user_data = <<-EOF
              #!/bin/bash
              set -xe
              yum update -y
              amazon-linux-extras enable corretto11
              yum install -y java-19-amazon-corretto-devel
              java -version
              echo "Java installation complete" > /home/ec2-user/java_status.txt
              EOF
  tags = {
    Name  = "devops-${var.stage}-instance"
    Stage = var.stage
  }
}

# Outputs
output "public_ip" {
  value = aws_instance.devops_ec2.public_ip
}

output "public_dns" {
  value = aws_instance.devops_ec2.public_dns
}
