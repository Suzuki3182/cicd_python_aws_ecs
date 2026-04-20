# ============================================================
# Root orchestrator — invokes all modules
# ============================================================

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

module "ecr" {
  source = "./modules/ecr-repo"

  project_name          = var.project_name
  environment           = var.environment
  repository_name       = var.ecr_repository_name
  image_retention_count = var.ecr_image_retention_count
}

# RDS is created before ECS so ECS can receive db_secret_arn at plan time.
# The RDS security group accepts the ECS SG ID as optional — it defaults to
# VPC-CIDR access when empty, which avoids the circular dependency.
module "rds" {
  source = "./modules/rds"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr_block
  private_subnet_ids = module.vpc.private_subnet_ids
  db_name            = var.db_name
  master_username    = var.db_master_username
  instance_class     = var.aurora_instance_class
  instances_count    = var.aurora_instances_count

  depends_on = [module.vpc]
}

module "s3" {
  source = "./modules/s3"

  project_name       = var.project_name
  environment        = var.environment
  bucket_name        = var.s3_bucket_name
  versioning_enabled = var.s3_versioning_enabled
}

module "ecs" {
  count  = var.enable_ecs ? 1 : 0
  source = "./modules/ecs-service"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr_block
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  ecr_image_uri      = "${module.ecr.repository_url}:${var.image_tag}"
  certificate_arn    = var.certificate_arn
  container_port     = var.container_port
  task_cpu           = var.ecs_task_cpu
  task_memory        = var.ecs_task_memory
  desired_count      = var.ecs_service_desired_count
  min_count          = var.ecs_service_min_count
  max_count          = var.ecs_service_max_count
  db_secret_arn      = module.rds.db_secret_arn
  s3_bucket_arn      = module.s3.bucket_arn

  depends_on = [module.vpc, module.ecr, module.rds, module.s3]
}

module "eks" {
  count  = var.enable_eks ? 1 : 0
  source = "./modules/eks-service"

  project_name               = var.project_name
  environment                = var.environment
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  public_subnet_ids          = module.vpc.public_subnet_ids
  kubernetes_version         = var.kubernetes_version
  endpoint_private_access    = var.eks_endpoint_private_access
  endpoint_public_access     = var.eks_endpoint_public_access
  node_instance_types        = var.eks_node_instance_types
  node_desired_size          = var.eks_node_desired_size
  node_min_size              = var.eks_node_min_size
  node_max_size              = var.eks_node_max_size
  create_oidc_provider       = var.enable_eks_oidc_provider
  enable_bedrock_irsa        = var.enable_bedrock_irsa
  bedrock_namespace          = var.bedrock_namespace
  bedrock_service_account    = var.bedrock_service_account
  bedrock_allowed_actions    = var.bedrock_allowed_actions
  allowed_bedrock_model_arns = var.allowed_bedrock_model_arns

  depends_on = [module.vpc]
}

module "monitoring" {
  count  = var.enable_ecs ? 1 : 0
  source = "./modules/monitoring"

  project_name     = var.project_name
  environment      = var.environment
  ecs_cluster_name = module.ecs[0].cluster_name
  ecs_service_name = module.ecs[0].service_name
  alb_arn_suffix   = module.ecs[0].alb_arn_suffix
  rds_cluster_id   = module.rds.cluster_id
  aws_region       = var.aws_region

  depends_on = [module.ecs, module.rds]
}
