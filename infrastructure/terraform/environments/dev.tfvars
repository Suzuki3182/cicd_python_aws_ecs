aws_region   = "us-east-1"
project_name = "cicd-python-ecs"
environment  = "dev"
vpc_cidr     = "10.0.0.0/16"

single_nat_gateway = true

ecs_task_cpu              = 256
ecs_task_memory           = 512
ecs_service_desired_count = 1
ecs_service_min_count     = 1
ecs_service_max_count     = 3

aurora_instance_class  = "db.t3.medium"
aurora_instances_count = 1

s3_bucket_name      = "cicd-python-ecs-dev-artifacts"
ecr_repository_name = "cicd-python-ecs"
image_tag           = "latest"

# Replace with a real ACM certificate ARN before applying.
certificate_arn = "arn:aws:acm:us-east-1:111111111111:certificate/00000000-0000-0000-0000-000000000000"
