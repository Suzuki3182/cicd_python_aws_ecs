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

variable "enable_ecs" {
  description = "Enable ECS resources"
  type        = bool
  default     = true
}

variable "enable_eks" {
  description = "Enable EKS resources"
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

variable "certificate_arn" {
  description = "ACM certificate ARN for the ALB HTTPS listener"
  type        = string
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

# ============================================================
# EKS
# ============================================================

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "eks_endpoint_private_access" {
  description = "Enable private EKS API endpoint"
  type        = bool
  default     = true
}

variable "eks_endpoint_public_access" {
  description = "Enable public EKS API endpoint"
  type        = bool
  default     = true
}

variable "eks_node_instance_types" {
  description = "EKS node group instance types"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_desired_size" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 2
}

variable "eks_node_min_size" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 5
}

variable "enable_eks_oidc_provider" {
  description = "Create EKS OIDC provider for IRSA"
  type        = bool
  default     = true
}

# ============================================================
# Amazon Bedrock (IRSA)
# ============================================================

variable "enable_bedrock_irsa" {
  description = "Create IRSA role for pods to call Amazon Bedrock"
  type        = bool
  default     = false
}

variable "bedrock_namespace" {
  description = "Kubernetes namespace of the Bedrock-enabled service account"
  type        = string
  default     = "app"
}

variable "bedrock_service_account" {
  description = "Kubernetes service account allowed to assume Bedrock IRSA role"
  type        = string
  default     = "bedrock-client"
}

variable "bedrock_allowed_actions" {
  description = "Allowed IAM actions for Bedrock access"
  type        = list(string)
  default = [
    "bedrock:InvokeModel",
    "bedrock:InvokeModelWithResponseStream",
    "bedrock:ListFoundationModels"
  ]
}

variable "allowed_bedrock_model_arns" {
  description = "Allowed model ARNs for Bedrock access"
  type        = list(string)
  default     = ["*"]
}
