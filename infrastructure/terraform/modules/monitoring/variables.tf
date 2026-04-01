variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "ecs_cluster_name" {
  type = string
}

variable "ecs_service_name" {
  type = string
}

variable "alb_arn_suffix" {
  type = string
}

variable "rds_cluster_id" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "sns_topic_arns" {
  type    = list(string)
  default = []
}
