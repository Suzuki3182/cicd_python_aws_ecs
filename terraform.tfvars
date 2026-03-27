# ============================================================
# Valores das variáveis - ajuste conforme seu ambiente
# ============================================================

aws_region   = "us-east-1"
project_name = "minha-app"
environment  = "prod"

# VPC
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
single_nat_gateway   = false # true em dev para economizar custos

# EKS
eks_cluster_version     = "1.29"
eks_node_instance_types = ["t3.medium"]
eks_node_min_size       = 2
eks_node_max_size       = 5
eks_node_desired_size   = 2

# RDS / Aurora
db_name                = "appdb"
db_master_username     = "dbadmin"
aurora_instance_class  = "db.t3.medium"
aurora_instances_count = 2

# Lambda
lambda_runtime     = "python3.12"
lambda_memory_size = 256
lambda_timeout     = 30

# S3 (nome deve ser globalmente único na AWS)
s3_bucket_name        = "test-terraform-state-bucket"
s3_versioning_enabled = true

# CI/CD
github_repo         = "meu-usuario/minha-app"
github_branch       = "main"
ecr_repository_name = "minha-app"
