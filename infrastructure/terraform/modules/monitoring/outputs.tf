output "dashboard_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${var.project_name}-${var.environment}"
}

output "ecs_cpu_alarm_arn" {
  value = aws_cloudwatch_metric_alarm.ecs_cpu_high.arn
}

output "task_failure_alarm_arn" {
  value = aws_cloudwatch_metric_alarm.ecs_task_failures.arn
}
