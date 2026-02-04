variable "aws_region" {
  description = "AWS region"
  default     = "ap-southeast-2"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "stage" {
  description = "Deployment stage (e.g., dev, prod)"
  default     = "dev"
}
variable "auto_stop_minutes" {
  description = "Minutes after which instance will shut down to save cost (0 to disable)"
  type        = number
  default     = 60
}
variable "bucket_name" {
  description = "Optional: provide a bucket name. If empty, Terraform will auto-generate a unique name."
  type        = string
  default     = ""
}
variable "project" {
  description = "Project identifier"
  type        = string
  default     = "assignment3"
}
