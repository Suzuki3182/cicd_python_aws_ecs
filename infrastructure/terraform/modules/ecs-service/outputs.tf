output "cluster_name" { value = aws_ecs_cluster.this.name }
output "service_name" { value = aws_ecs_service.app.name }
output "service_security_group_id" { value = aws_security_group.service.id }
output "alb_dns_name" { value = aws_lb.this.dns_name }
output "alb_arn_suffix" { value = aws_lb.this.arn_suffix }
output "target_group_arn_suffix" { value = aws_lb_target_group.blue.arn_suffix }
output "task_definition_arn" { value = aws_ecs_task_definition.app.arn }
