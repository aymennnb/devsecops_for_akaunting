terraform {
  backend "s3" {
    bucket         = "votre-bucket-terraform-state"
    key            = "akaunting/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}
