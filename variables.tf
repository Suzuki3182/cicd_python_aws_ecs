# ============================================================
# Variáveis Globais
# ============================================================

variable "aws_region" {
  description = "Região AWS onde os recursos serão provisionados"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto (usado em tags e nomes de recursos)"
  type        = string
}

variable "environment" {
  description = "Ambiente de deploy (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "O ambiente deve ser: dev, staging ou prod."
  }
}

# ============================================================
# VPC
# ============================================================

variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Lista de Availability Zones a utilizar"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs das subnets públicas"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs das subnets privadas"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "single_nat_gateway" {
  description = "Usar apenas 1 NAT Gateway (economiza custos em dev/staging)"
  type        = bool
  default     = false
}

# ============================================================
# EKS
# ============================================================

variable "eks_cluster_version" {
  description = "Versão do Kubernetes no EKS"
  type        = string
  default     = "1.29"
}

variable "eks_node_instance_types" {
  description = "Tipos de instância para os nós do EKS"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_min_size" {
  description = "Número mínimo de nós no node group"
  type        = number
  default     = 2
}

variable "eks_node_max_size" {
  description = "Número máximo de nós no node group"
  type        = number
  default     = 5
}

variable "eks_node_desired_size" {
  description = "Número desejado de nós no node group"
  type        = number
  default     = 2
}

# ============================================================
# RDS / Aurora
# ============================================================

variable "db_name" {
  description = "Nome do banco de dados inicial"
  type        = string
  default     = "appdb"
}

variable "db_master_username" {
  description = "Usuário master do banco de dados"
  type        = string
  default     = "dbadmin"
  sensitive   = true
}

variable "aurora_instance_class" {
  description = "Classe de instância para o Aurora"
  type        = string
  default     = "db.t3.medium"
}

variable "aurora_instances_count" {
  description = "Número de instâncias no cluster Aurora"
  type        = number
  default     = 2
}

# ============================================================
# Lambda
# ============================================================

variable "lambda_runtime" {
  description = "Runtime da função Lambda"
  type        = string
  default     = "python3.12"
}

variable "lambda_memory_size" {
  description = "Memória alocada para a Lambda (MB)"
  type        = number
  default     = 256
}

variable "lambda_timeout" {
  description = "Timeout da Lambda em segundos"
  type        = number
  default     = 30
}

# ============================================================
# S3
# ============================================================

variable "s3_bucket_name" {
  description = "Nome do bucket S3 (deve ser globalmente único)"
  type        = string
}

variable "s3_versioning_enabled" {
  description = "Habilitar versionamento no S3"
  type        = bool
  default     = true
}

# ============================================================
# CI/CD
# ============================================================

variable "github_repo" {
  description = "Repositório GitHub no formato 'owner/repo'"
  type        = string
  default     = ""
}

variable "github_branch" {
  description = "Branch do GitHub a monitorar"
  type        = string
  default     = "main"
}

variable "ecr_repository_name" {
  description = "Nome do repositório ECR para imagens Docker"
  type        = string
  default     = "app"
}
