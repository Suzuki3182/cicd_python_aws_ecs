variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "db_name" {
  type    = string
  default = "appdb"
}
variable "master_username" {
  type      = string
  default   = "dbadmin"
  sensitive = true
}
variable "instance_class" {
  type    = string
  default = "db.t3.medium"
}
variable "instances_count" {
  type    = number
  default = 2
}
variable "app_security_group_id" {
  description = "Security group ID of the application (ECS service) allowed to reach RDS"
  type        = string
  default     = ""
}
