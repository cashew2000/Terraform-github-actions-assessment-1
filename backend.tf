terraform {
  backend "s3" {
    bucket         = "assignment1-terraform-state-bucket"
    key            = "assessment-4/dev/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
