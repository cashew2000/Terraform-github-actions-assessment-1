########################################################
# s3.tf - S3 bucket + versioning + lifecycle for logs
########################################################

# random suffix for bucket name when user doesn't provide one
resource "random_id" "suffix" {
  byte_length = 4
}

# if you prefer to pass bucket_name via variables use that; otherwise an automatic name is used
resource "aws_s3_bucket" "app_logs" {
  bucket = var.bucket_name != "" ? var.bucket_name : format("%s-logs-%s", var.stage, random_id.suffix.hex)

  acl    = "private"

  tags = {
    Name  = format("%s-logs", var.stage)
    Stage = var.stage
    Owner = "preran"
  }
}

# enable server-side versioning
resource "aws_s3_bucket_versioning" "app_logs_ver" {
  bucket = aws_s3_bucket.app_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# lifecycle rule to expire objects after 7 days
resource "aws_s3_bucket_lifecycle_configuration" "app_logs_lifecycle" {
  bucket = aws_s3_bucket.app_logs.id

  rule {
    id     = "expire-logs-7-days"
    status = "Enabled"

    filter {
      prefix = "logs/" # we will upload app logs under logs/ ; adjust if needed
    }

    expiration {
      days = 7
    }
  }
}

# (optional) block public access prevention - keep bucket private by default
resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.app_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.app_logs.bucket
  description = "S3 bucket created for application logs"
}
