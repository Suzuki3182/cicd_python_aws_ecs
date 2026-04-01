# ============================================================
# Módulo RDS - Aurora PostgreSQL Serverless-compatible Cluster
# ============================================================

# -----------------------------------------------------------
# Gera senha aleatória para o master user
# -----------------------------------------------------------
resource "random_password" "db_master" {
  length           = 24
  special          = true
  override_special = "!#$%^&*()-_=+[]{}|;:,.<>?"
}

# -----------------------------------------------------------
# Armazena credenciais no Secrets Manager (nunca hardcode!)
# -----------------------------------------------------------
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}/${var.environment}/rds/credentials"
  description             = "Credenciais do banco Aurora PostgreSQL"
  recovery_window_in_days = 7 # Período de recuperação antes de deletar permanentemente

  tags = {
    Name = "${var.project_name}-${var.environment}-db-secret"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.db_master.result
    host     = aws_rds_cluster.main.endpoint
    port     = 5432
    dbname   = var.db_name
    engine   = "aurora-postgresql"
  })
}

# -----------------------------------------------------------
# Subnet Group (subnets privadas apenas)
# -----------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-${var.environment}-db-subnet-group"
  description = "Subnet group para o Aurora ${var.project_name}-${var.environment}"
  subnet_ids  = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  }
}

# -----------------------------------------------------------
# Security Group do banco (restringe acesso)
# -----------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Acesso controlado ao Aurora PostgreSQL"
  vpc_id      = var.vpc_id

  # Allow ECS service security group to reach the database
  dynamic "ingress" {
    for_each = var.app_security_group_id != "" ? [var.app_security_group_id] : []
    content {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [ingress.value]
      description     = "ECS service access to database"
    }
  }

  # Allow all traffic within the VPC CIDR (covers cases where SG is not provided)
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "VPC-internal access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow outbound within VPC only"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-sg"
  }
}

# -----------------------------------------------------------
# KMS Key para criptografia do banco
# -----------------------------------------------------------
resource "aws_kms_key" "rds" {
  description             = "KMS para criptografia do Aurora ${var.project_name}-${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-kms"
  }
}

# -----------------------------------------------------------
# Cluster Aurora PostgreSQL
# -----------------------------------------------------------
resource "aws_rds_cluster" "main" {
  cluster_identifier      = "${var.project_name}-${var.environment}-aurora"
  engine                  = "aurora-postgresql"
  engine_version          = "15.4"
  database_name           = var.db_name
  master_username         = var.master_username
  master_password         = random_password.db_master.result

  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.rds.id]

  # Criptografia em repouso
  storage_encrypted       = true
  kms_key_id              = aws_kms_key.rds.arn

  # Backups automáticos (7 dias)
  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"    # UTC - janela de menor tráfego
  preferred_maintenance_window = "Mon:04:00-Mon:05:00"

  # Snapshot final ao deletar (proteção contra delete acidental)
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-${var.environment}-final-snapshot"
  deletion_protection       = true # Impede delete acidental em produção

  # Habilita CloudWatch Logs
  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Habilita Data API (acesso HTTP ao banco, útil para Lambda)
  enable_http_endpoint = true

  tags = {
    Name = "${var.project_name}-${var.environment}-aurora"
  }
}

# -----------------------------------------------------------
# Instâncias do Cluster Aurora
# -----------------------------------------------------------
resource "aws_rds_cluster_instance" "main" {
  count = var.instances_count

  identifier         = "${var.project_name}-${var.environment}-aurora-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  # Performance Insights para monitoramento detalhado de queries
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  performance_insights_kms_key_id       = aws_kms_key.rds.arn

  # Monitoramento avançado (métricas do SO)
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  auto_minor_version_upgrade = true

  tags = {
    Name = "${var.project_name}-${var.environment}-aurora-instance-${count.index + 1}"
    Role = count.index == 0 ? "writer" : "reader"
  }
}

# -----------------------------------------------------------
# IAM Role para Enhanced Monitoring do RDS
# -----------------------------------------------------------
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-${var.environment}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  role       = aws_iam_role.rds_monitoring.name
}

# -----------------------------------------------------------
# Alarme CloudWatch - CPU do Aurora
# -----------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "aurora_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-aurora-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU do Aurora acima de 80%"
  alarm_actions       = [] # Adicione ARN do SNS topic para notificações

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.main.cluster_identifier
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-aurora-cpu-alarm"
  }
}
