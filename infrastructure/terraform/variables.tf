# ============================================================
# Global
# ============================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name (used in resource names and tags)"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be: dev, staging, or prod."
  }
}

# ============================================================
# VPC
# ============================================================

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of Availability Zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway (reduces cost in dev/staging)"
  type        = bool
  default     = false
}

# ============================================================
# ECS
# ============================================================

variable "ecs_task_cpu" {
  description = "CPU units for ECS task (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 512
}

variable "ecs_task_memory" {
  description = "Memory (MB) for ECS task"
  type        = number
  default     = 1024
}

variable "ecs_service_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "ecs_service_min_count" {
  description = "Minimum number of ECS tasks (auto-scaling)"
  type        = number
  default     = 1
}

variable "ecs_service_max_count" {
  description = "Maximum number of ECS tasks (auto-scaling)"
  type        = number
  default     = 10
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 8000
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

# ============================================================
# ECR
# ============================================================

variable "ecr_repository_name" {
  description = "ECR repository name for Docker images"
  type        = string
  default     = "app"
}

variable "ecr_image_retention_count" {
  description = "Number of tagged images to retain"
  type        = number
  default     = 10
}

# ============================================================
# RDS / Aurora
# ============================================================

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "appdb"
}

variable "db_master_username" {
  description = "Database master username"
  type        = string
  default     = "dbadmin"
  sensitive   = true
}

variable "aurora_instance_class" {
  description = "Aurora instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "aurora_instances_count" {
  description = "Number of instances in Aurora cluster"
  type        = number
  default     = 2
}

# ============================================================
# S3
# ============================================================

variable "s3_bucket_name" {
  description = "S3 bucket name (must be globally unique)"
  type        = string
}

variable "s3_versioning_enabled" {
  description = "Enable S3 versioning"
  type        = bool
  default     = true
}

# ============================================================
# GitHub Actions / OIDC
# ============================================================

variable "github_repo" {
  description = "GitHub repository in format 'owner/repo'"
  type        = string
  default     = ""
}

variable "github_branch" {
  description = "GitHub branch to monitor"
  type        = string
  default     = "main"
}
