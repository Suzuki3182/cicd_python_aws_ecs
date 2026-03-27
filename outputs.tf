# ============================================================
# Outputs consolidados da infraestrutura
# ============================================================

output "vpc_id" {
  description = "ID da VPC criada"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs das subnets públicas"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas"
  value       = module.vpc.private_subnet_ids
}

output "eks_cluster_name" {
  description = "Nome do cluster EKS"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint do cluster EKS"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "eks_kubeconfig_command" {
  description = "Comando para configurar o kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "rds_cluster_endpoint" {
  description = "Endpoint de escrita do cluster Aurora"
  value       = module.rds.cluster_endpoint
  sensitive   = true
}

output "rds_reader_endpoint" {
  description = "Endpoint de leitura do cluster Aurora"
  value       = module.rds.reader_endpoint
  sensitive   = true
}

output "db_secret_arn" {
  description = "ARN do Secret com credenciais do banco"
  value       = module.rds.db_secret_arn
}

output "s3_bucket_name" {
  description = "Nome do bucket S3"
  value       = module.s3.bucket_name
}

output "s3_bucket_arn" {
  description = "ARN do bucket S3"
  value       = module.s3.bucket_arn
}

output "lambda_function_name" {
  description = "Nome da função Lambda"
  value       = module.lambda.function_name
}

output "api_gateway_url" {
  description = "URL base da API Gateway"
  value       = module.lambda.api_gateway_url
}

output "ecr_repository_url" {
  description = "URL do repositório ECR"
  value       = module.cicd.ecr_repository_url
}

output "codepipeline_name" {
  description = "Nome do pipeline CI/CD"
  value       = module.cicd.pipeline_name
}
