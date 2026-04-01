# ============================================================
# Monitoring — CloudWatch dashboards, alarms, log insights
# ============================================================

locals {
  prefix = "${var.project_name}-${var.environment}"
}

# --- CloudWatch Dashboard ---
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = local.prefix

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "ECS CPU & Memory Utilization"
          metrics = [
            ["AWS/ECS", "CPUUtilization",    "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "ALB Request Count & Latency"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount",         "LoadBalancer", var.alb_arn_suffix],
            ["AWS/ApplicationELB", "TargetResponseTime",   "LoadBalancer", var.alb_arn_suffix]
          ]
          period = 60
          stat   = "Sum"
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "RDS CPU & Connections"
          metrics = [
            ["AWS/RDS", "CPUUtilization",    "DBClusterIdentifier", var.rds_cluster_id],
            ["AWS/RDS", "DatabaseConnections", "DBClusterIdentifier", var.rds_cluster_id]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Agent Actions Log"
          query   = "SOURCE '/claude/agent' | fields @timestamp, @message | sort @timestamp desc | limit 50"
          region  = var.aws_region
          view    = "table"
        }
      }
    ]
  })
}

# --- ECS CPU Alarm ---
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${local.prefix}-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS CPU > 80% for 2 minutes"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_actions = var.sns_topic_arns
  ok_actions    = var.sns_topic_arns
}

# --- ECS Task Count Alarm (auto-rollback trigger) ---
resource "aws_cloudwatch_metric_alarm" "ecs_task_failures" {
  alarm_name          = "${local.prefix}-ecs-task-failures"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "TaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Minimum"
  threshold           = 3
  alarm_description   = "ECS task failure count >= 3 — triggers auto-rollback"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_actions = var.sns_topic_arns
}

# --- ALB 5xx Alarm ---
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${local.prefix}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = var.sns_topic_arns
}

# --- Agent metrics namespace ---
resource "aws_cloudwatch_log_metric_filter" "agent_actions" {
  name           = "${local.prefix}-agent-actions"
  pattern        = "{ $.action = * }"
  log_group_name = "/claude/agent"

  metric_transformation {
    name      = "AgentActions"
    namespace = "Claude/Agent"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "automation_failures" {
  name           = "${local.prefix}-automation-failures"
  pattern        = "{ $.status = \"failed\" }"
  log_group_name = "/claude/agent"

  metric_transformation {
    name      = "AutomationFailures"
    namespace = "Claude/Agent"
    value     = "1"
  }
}
