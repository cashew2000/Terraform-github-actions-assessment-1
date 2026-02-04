##############################################################
# Terraform configuration for Assessment 1
# Launch Ubuntu EC2, install Java, clone repo, run app, auto-shutdown
##############################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

##############################################################
# Provider
##############################################################
provider "aws" {
  region = var.aws_region
}

##############################################################
# Data source – latest Ubuntu 22.04 AMI
##############################################################
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

##############################################################
# Security group
##############################################################
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

##############################################################
# EC2 Instance
##############################################################
resource "aws_instance" "devops_ec2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.devops_key.key_name
  vpc_security_group_ids = [aws_security_group.devops_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name #adding IAM profile
  # Pass parameters into user-data template
  user_data = templatefile("${path.module}/scripts/user_data.tpl", {
    stage = var.stage
  })

  tags = {
    Name    = "${var.project}-ec2-${var.stage}"
    Project = var.project
    Stage   = var.stage
  }
}


##############################################################
# Outputs
##############################################################
output "public_ip" {
  value       = aws_instance.devops_ec2.public_ip
  description = "Public IP of EC2 instance"
}

output "public_dns" {
  value       = aws_instance.devops_ec2.public_dns
  description = "Public DNS of EC2 instance"
}
