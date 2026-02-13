provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      environment = var.environment,
      project     = "terraform-drift",
      owner       = "ravi"
    }
  }
}

terraform {
  backend "s3" {
  }
}
