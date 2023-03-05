provider "aws" {
  region = "eu-central-1"
}

resource "aws_s3_bucket" "taxify_state_bucket" {
  bucket = "taxify-bucket"

  lifecycle {
    prevent_destroy = true
  }

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "taxify-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

#backend for my state file resources
#To run this script successfully comment the 
#Terraform backend block below. After successfully
#creating the resources need, migrate the state file
#to the newly created bucket.
terraform {
  backend "s3" {
    bucket         = "taxify-bucket"
    key            = "global/s3/backend.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "taxify-lock"
    encrypt        = true
  }
}