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
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs.service_name
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = module.ecs.alb_dns_name
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
  value       = module.monitoring.dashboard_url
}
