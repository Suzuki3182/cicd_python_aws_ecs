variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "github_branch" {
  type    = string
  default = "main"
}

variable "ecr_repository_name" {
  type    = string
  default = "app"
}

variable "eks_cluster_name" {
  type = string
}

variable "s3_artifacts_bucket" {
  type = string
}
