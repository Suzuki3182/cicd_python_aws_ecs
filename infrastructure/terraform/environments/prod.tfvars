aws_region   = "us-east-1"
project_name = "cicd-python-ecs"
environment  = "prod"
vpc_cidr     = "10.2.0.0/16"

single_nat_gateway = false

ecs_task_cpu              = 1024
ecs_task_memory           = 2048
ecs_service_desired_count = 3
ecs_service_min_count     = 2
ecs_service_max_count     = 20

aurora_instance_class  = "db.r6g.large"
aurora_instances_count = 2

s3_bucket_name      = "cicd-python-ecs-prod-artifacts"
ecr_repository_name = "cicd-python-ecs"
image_tag           = "latest"

# Set to your ACM certificate ARN before applying
certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERTIFICATE_ID"
