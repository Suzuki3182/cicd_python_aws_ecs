variable "project_name" { type = string }
variable "environment" { type = string }
variable "runtime" {
  type    = string
  default = "python3.12"
}
variable "memory_size" {
  type    = number
  default = 256
}
variable "timeout" {
  type    = number
  default = 30
}
variable "s3_bucket_arn" { type = string }
variable "db_secret_arn" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
