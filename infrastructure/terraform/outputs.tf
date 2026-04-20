output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = module.ecr.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = var.enable_ecs ? module.ecs[0].cluster_name : null
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = var.enable_ecs ? module.ecs[0].service_name : null
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = var.enable_ecs ? module.ecs[0].alb_dns_name : null
}

output "rds_cluster_endpoint" {
  description = "RDS cluster writer endpoint"
  value       = module.rds.cluster_endpoint
  sensitive   = true
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret for DB credentials"
  value       = module.rds.db_secret_arn
}

output "s3_bucket_name" {
  description = "S3 artifacts bucket name"
  value       = module.s3.bucket_name
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = var.enable_ecs ? module.monitoring[0].dashboard_url : null
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = var.enable_eks ? module.eks[0].cluster_name : null
}

output "eks_cluster_endpoint" {
  description = "EKS control plane endpoint"
  value       = var.enable_eks ? module.eks[0].cluster_endpoint : null
}

output "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  value       = var.enable_eks ? module.eks[0].oidc_provider_arn : null
}

output "bedrock_irsa_role_arn" {
  description = "IAM role ARN for Bedrock IRSA"
  value       = var.enable_eks ? module.eks[0].bedrock_irsa_role_arn : null
}
