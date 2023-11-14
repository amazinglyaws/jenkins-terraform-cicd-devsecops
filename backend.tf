terraform {
  backend "s3" {
    bucket         = "terraform-jenkins-cicd-bucket"
    key            = "my-terraform-environment/main"
    region         = "us-east-1"
    dynamodb_table = "terraform-jenkins-dynamodb-table"
  }
}
