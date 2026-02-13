data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "main" {
  bucket = "drift-${data.aws_caller_identity.current.account_id}-${var.environment}"
}
