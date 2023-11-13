terraform {
  backend "s3" {
    bucket         = "terraform-cicd-bucket"
    key            = "my-terraform-environment/main"
    region         = "us-east-1"
    dynamodb_table = "terra-dynamodb-table"
  }
}
