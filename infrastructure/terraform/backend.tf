terraform {
  backend "s3" {
    bucket         = "tf-state-cicd-python-aws-ecs"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "tf-state-lock"
  }
}
