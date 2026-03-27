# ============================================================
# Módulo Lambda + API Gateway HTTP API (v2)
# ============================================================

# -----------------------------------------------------------
# Bucket S3 para artefatos da Lambda
# -----------------------------------------------------------
data "aws_s3_bucket" "artifacts" {
  bucket = split(":", var.s3_bucket_arn)[5]
}

# -----------------------------------------------------------
# Arquivo ZIP da Lambda (placeholder - substitua pelo seu código)
# -----------------------------------------------------------
data "archive_file" "lambda" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"

  source {
    content  = <<-EOF
      import json
      import boto3
      import logging

      logger = logging.getLogger()
      logger.setLevel(logging.INFO)

      def handler(event, context):
          """Handler principal da Lambda."""
          logger.info(f"Evento recebido: {json.dumps(event)}")

          try:
              # Lógica da aplicação aqui
              response = {
                  "statusCode": 200,
                  "headers": {
                      "Content-Type": "application/json",
                      "Access-Control-Allow-Origin": "*"
                  },
                  "body": json.dumps({
                      "message": "API funcionando!",
                      "path": event.get("rawPath", "/"),
                      "method": event.get("requestContext", {}).get("http", {}).get("method", "GET")
                  })
              }
              return response

          except Exception as e:
              logger.error(f"Erro: {str(e)}")
              return {
                  "statusCode": 500,
                  "body": json.dumps({"error": "Erro interno do servidor"})
              }
    EOF
    filename = "main.py"
  }
}

# -----------------------------------------------------------
# IAM Role da Lambda (Least Privilege)
# -----------------------------------------------------------
resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Política customizada da Lambda
resource "aws_iam_role_policy" "lambda_custom" {
  name = "${var.project_name}-${var.environment}-lambda-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Acesso ao S3 (apenas leitura/escrita no bucket específico)
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      },
      # Acesso ao Secrets Manager (credenciais do banco)
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [var.db_secret_arn]
      },
      # Acesso ao CloudWatch Logs
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      # Necessário para Lambda em VPC (criar ENIs)
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ]
        Resource = "*"
      },
      # X-Ray para tracing
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------
# Security Group da Lambda (em VPC)
# -----------------------------------------------------------
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-${var.environment}-lambda-sg"
  description = "Security Group da função Lambda"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic (S3, Secrets Manager via endpoints)"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-lambda-sg"
  }
}

# -----------------------------------------------------------
# CloudWatch Log Group da Lambda
# -----------------------------------------------------------
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-api"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-${var.environment}-lambda-logs"
  }
}

# -----------------------------------------------------------
# Função Lambda
# -----------------------------------------------------------
resource "aws_lambda_function" "api" {
  function_name = "${var.project_name}-${var.environment}-api"
  description   = "API principal do ${var.project_name} (${var.environment})"
  role          = aws_iam_role.lambda.arn
  handler       = "main.handler"
  runtime       = var.runtime
  memory_size   = var.memory_size
  timeout       = var.timeout

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  # Lambda em VPC para acesso ao RDS
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  # Variáveis de ambiente (credenciais via Secrets Manager, não hardcoded)
  environment {
    variables = {
      ENVIRONMENT    = var.environment
      DB_SECRET_ARN  = var.db_secret_arn
      S3_BUCKET      = split(":", var.s3_bucket_arn)[5]
      LOG_LEVEL      = var.environment == "prod" ? "WARNING" : "DEBUG"
    }
  }

  # X-Ray Tracing ativo
  tracing_config {
    mode = "Active"
  }

  # Reserva de concorrência (evita throttling crítico)
  reserved_concurrent_executions = 100

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role.lambda,
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-api-lambda"
  }
}

# -----------------------------------------------------------
# API Gateway HTTP API (v2) - mais barato e rápido que REST API
# -----------------------------------------------------------
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-${var.environment}-api"
  protocol_type = "HTTP"
  description   = "API Gateway para ${var.project_name} ${var.environment}"

  # CORS configuração (ajuste as origens permitidas)
  cors_configuration {
    allow_headers = ["Content-Type", "Authorization", "X-Api-Key"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_origins = var.environment == "prod" ? ["https://meusite.com"] : ["*"]
    max_age       = 300
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-api-gw"
  }
}

# Stage de deploy (auto-deploy habilitado)
resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = var.environment
  auto_deploy = true

  # Logs de acesso da API Gateway
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      sourceIp       = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      protocol       = "$context.protocol"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
      integrationLatency = "$context.integrationLatency"
    })
  }

  default_route_settings {
    throttling_burst_limit   = 1000  # Requisições simultâneas máximas
    throttling_rate_limit    = 500   # Requisições por segundo
    detailed_metrics_enabled = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-api-stage"
  }
}

# Log Group para API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}"
  retention_in_days = 30
}

# Integração API Gateway -> Lambda
resource "aws_apigatewayv2_integration" "lambda" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0" # Formato mais eficiente
}

# Rota catch-all (qualquer método, qualquer path)
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Permissão para API Gateway invocar a Lambda
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# -----------------------------------------------------------
# Alarme CloudWatch - Erros da Lambda
# -----------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Lambda com mais de 10 erros por minuto"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.api.function_name
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-lambda-errors-alarm"
  }
}
