variable "aws_region" {
  description = "AWS region"
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"
}

variable "stage" {
  description = "Deployment stage (e.g., dev, prod)"
  default     = "dev"
}
