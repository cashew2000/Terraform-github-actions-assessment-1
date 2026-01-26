resource "aws_key_pair" "devops_key" {
  key_name   = "devops-assignment3-${var.stage}"

  # 👇 Replace the path if your .pub file is elsewhere
  public_key = file("${path.module}/devops-assignment3.pub")

  tags = {
    Name  = "devops-assignment3-key"
    Stage = var.stage
  }
}
