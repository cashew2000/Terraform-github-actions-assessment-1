########################################################
# iam.tf - IAM Role, Policy and Instance Profile for EC2
########################################################

# 1️⃣ IAM Policy: Allow EC2 to write logs to the S3 bucket
resource "aws_iam_policy" "s3_write_policy" {
  name = "${var.project}-s3-write-${var.stage}"
  description = "Allow EC2 instances to upload logs to the S3 app_logs bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "${aws_s3_bucket.app_logs.arn}",
          "${aws_s3_bucket.app_logs.arn}/*"
        ]
      }
    ]
  })
}

# 2️⃣ IAM Role: trusted by EC2 service
resource "aws_iam_role" "ec2_s3_role" {
  name = "${var.project}-ec2-role-${var.stage}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# 3️⃣ Attach the policy to the role
resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = aws_iam_policy.s3_write_policy.arn
}

# 4️⃣ Instance Profile (EC2 uses this to assume the role)
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.project}-instance-profile-${var.stage}"
  role = aws_iam_role.ec2_s3_role.name
}

# 5️⃣ Output (optional)
output "instance_profile_name" {
  value       = aws_iam_instance_profile.ec2_instance_profile.name
  description = "IAM Instance Profile attached to EC2"
}
