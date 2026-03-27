# ============================================================
# Orquestrador principal - invoca todos os módulos
# ============================================================

# -----------------------------------------------------------
# Módulo: VPC
# -----------------------------------------------------------
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway
}

# -----------------------------------------------------------
# Módulo: EKS
# -----------------------------------------------------------
module "eks" {
  source = "./modules/eks"

  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  cluster_version     = var.eks_cluster_version
  node_instance_types = var.eks_node_instance_types
  node_min_size       = var.eks_node_min_size
  node_max_size       = var.eks_node_max_size
  node_desired_size   = var.eks_node_desired_size

  depends_on = [module.vpc]
}

# -----------------------------------------------------------
# Módulo: RDS Aurora
# -----------------------------------------------------------
module "rds" {
  source = "./modules/rds"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  db_name               = var.db_name
  master_username       = var.db_master_username
  instance_class        = var.aurora_instance_class
  instances_count       = var.aurora_instances_count
  eks_security_group_id = module.eks.node_security_group_id

  depends_on = [module.vpc]
}

# -----------------------------------------------------------
# Módulo: S3
# -----------------------------------------------------------
module "s3" {
  source = "./modules/s3"

  project_name       = var.project_name
  environment        = var.environment
  bucket_name        = var.s3_bucket_name
  versioning_enabled = var.s3_versioning_enabled
}

# -----------------------------------------------------------
# Módulo: Lambda + API Gateway
# -----------------------------------------------------------
module "lambda" {
  source = "./modules/lambda"

  project_name       = var.project_name
  environment        = var.environment
  runtime            = var.lambda_runtime
  memory_size        = var.lambda_memory_size
  timeout            = var.lambda_timeout
  s3_bucket_arn      = module.s3.bucket_arn
  db_secret_arn      = module.rds.db_secret_arn
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  depends_on = [module.rds, module.s3]
}

# -----------------------------------------------------------
# Módulo: CI/CD Pipeline
# -----------------------------------------------------------
module "cicd" {
  source = "./modules/cicd"

  project_name        = var.project_name
  environment         = var.environment
  aws_region          = var.aws_region
  github_repo         = var.github_repo
  github_branch       = var.github_branch
  ecr_repository_name = var.ecr_repository_name
  eks_cluster_name    = module.eks.cluster_name
  s3_artifacts_bucket = module.s3.bucket_name

  depends_on = [module.eks, module.s3]
}
