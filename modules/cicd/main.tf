# ============================================================
# Módulo CI/CD - CodePipeline + CodeBuild + ECR
# Fluxo: GitHub → CodePipeline → CodeBuild (build/test) → ECR → EKS Deploy
# ============================================================

data "aws_caller_identity" "current" {}

# -----------------------------------------------------------
# ECR - Repositório de imagens Docker
# -----------------------------------------------------------
resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-${var.environment}-${var.ecr_repository_name}"
  image_tag_mutability = "MUTABLE"

  # Scan automático de vulnerabilidades ao fazer push
  image_scanning_configuration {
    scan_on_push = true
  }

  # Criptografia com KMS
  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ecr"
  }
}

# Política de lifecycle do ECR (mantém apenas as últimas 10 imagens)
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Manter apenas as últimas 10 imagens tagged"
        selection = {
          tagStatus   = "tagged"
          tagPrefixList = ["v"]
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Remover imagens não-taggeadas após 7 dias"
        selection = {
          tagStatus = "untagged"
          countType = "sinceImagePushed"
          countUnit = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      }
    ]
  })
}

# -----------------------------------------------------------
# Conexão com GitHub (Star Code Connections)
# Após criação, é necessário autenticar manualmente no console AWS
# -----------------------------------------------------------
resource "aws_codestarconnections_connection" "github" {
  name          = "${var.project_name}-${var.environment}-github"
  provider_type = "GitHub"

  tags = {
    Name = "${var.project_name}-${var.environment}-github-connection"
  }
}

# -----------------------------------------------------------
# IAM Role do CodePipeline
# -----------------------------------------------------------
resource "aws_iam_role" "codepipeline" {
  name = "${var.project_name}-${var.environment}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codepipeline.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline" {
  name = "${var.project_name}-${var.environment}-codepipeline-policy"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:GetObjectVersion", "s3:GetBucketVersioning",
          "s3:PutObjectAcl", "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_artifacts_bucket}",
          "arn:aws:s3:::${var.s3_artifacts_bucket}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["codestar-connections:UseConnection"]
        Resource = aws_codestarconnections_connection.github.arn
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------
# IAM Role do CodeBuild
# -----------------------------------------------------------
resource "aws_iam_role" "codebuild" {
  name = "${var.project_name}-${var.environment}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "codebuild" {
  name = "${var.project_name}-${var.environment}-codebuild-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Logs no CloudWatch
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      },
      # Artefatos no S3
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"]
        Resource = [
          "arn:aws:s3:::${var.s3_artifacts_bucket}",
          "arn:aws:s3:::${var.s3_artifacts_bucket}/*"
        ]
      },
      # Push para o ECR
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      },
      # Deploy no EKS
      {
        Effect = "Allow"
        Action = ["eks:DescribeCluster"]
        Resource = "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.eks_cluster_name}"
      },
      # SSM Parameter Store (configurações)
      {
        Effect = "Allow"
        Action = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/*"
      }
    ]
  })
}

# -----------------------------------------------------------
# CodeBuild - Projeto de Build e Testes
# -----------------------------------------------------------
resource "aws_codebuild_project" "build" {
  name          = "${var.project_name}-${var.environment}-build"
  description   = "Build, test e push da imagem Docker para ECR"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 20 # minutos

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml" # Arquivo na raiz do repositório
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true # Necessário para build Docker

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }

    environment_variable {
      name  = "ECR_REPOSITORY_URI"
      value = aws_ecr_repository.app.repository_url
    }

    environment_variable {
      name  = "EKS_CLUSTER_NAME"
      value = var.eks_cluster_name
    }

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }
  }

  # Cache no S3 para acelerar builds subsequentes
  cache {
    type     = "S3"
    location = "${var.s3_artifacts_bucket}/codebuild-cache"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.project_name}-${var.environment}-build"
      stream_name = "build-log"
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-codebuild"
  }
}

# -----------------------------------------------------------
# CodePipeline - Orquestra todo o fluxo CI/CD
# -----------------------------------------------------------
resource "aws_codepipeline" "main" {
  name     = "${var.project_name}-${var.environment}-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = var.s3_artifacts_bucket
    type     = "S3"
  }

  # Stage 1: Source - Monitora o GitHub
  stage {
    name = "Source"

    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = var.github_repo
        BranchName       = var.github_branch
        DetectChanges    = true
      }
    }
  }

  # Stage 2: Build - Compila, testa e cria imagem Docker
  stage {
    name = "Build"

    action {
      name             = "Build_and_Test"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }

  # Stage 3: Aprovação manual (apenas em prod)
  dynamic "stage" {
    for_each = var.environment == "prod" ? [1] : []
    content {
      name = "Manual_Approval"

      action {
        name     = "Approve_Deploy"
        category = "Approval"
        owner    = "AWS"
        provider = "Manual"
        version  = "1"

        configuration = {
          CustomData = "Aprovar deploy para produção do ${var.project_name}?"
          # NotificationArn = "arn:aws:sns:..." # Adicione SNS para notificação por email
        }
      }
    }
  }

  # Stage 4: Deploy no EKS via CodeBuild
  stage {
    name = "Deploy"

    action {
      name            = "Deploy_to_EKS"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.deploy.name
      }
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-pipeline"
  }
}

# -----------------------------------------------------------
# CodeBuild - Projeto de Deploy no EKS
# -----------------------------------------------------------
resource "aws_codebuild_project" "deploy" {
  name          = "${var.project_name}-${var.environment}-deploy"
  description   = "Deploy da imagem Docker no cluster EKS"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 15

  source {
    type = "CODEPIPELINE"
    buildspec = <<-EOF
      version: 0.2
      phases:
        install:
          commands:
            - curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            - chmod +x kubectl && mv kubectl /usr/local/bin/
        pre_build:
          commands:
            - aws eks update-kubeconfig --region $AWS_DEFAULT_REGION --name $EKS_CLUSTER_NAME
            - IMAGE_TAG=$(cat imageTag.txt)
        build:
          commands:
            - echo "Fazendo deploy no EKS..."
            - kubectl set image deployment/app app=$ECR_REPOSITORY_URI:$IMAGE_TAG -n $ENVIRONMENT
            - kubectl rollout status deployment/app -n $ENVIRONMENT --timeout=300s
        post_build:
          commands:
            - echo "Deploy concluído com sucesso!"
            - kubectl get pods -n $ENVIRONMENT
    EOF
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "EKS_CLUSTER_NAME"
      value = var.eks_cluster_name
    }

    environment_variable {
      name  = "ECR_REPOSITORY_URI"
      value = aws_ecr_repository.app.repository_url
    }

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.project_name}-${var.environment}-deploy"
      stream_name = "deploy-log"
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-codebuild-deploy"
  }
}

# -----------------------------------------------------------
# Notificação do Pipeline via SNS (opcional)
# -----------------------------------------------------------
resource "aws_codestarnotifications_notification_rule" "pipeline" {
  name        = "${var.project_name}-${var.environment}-pipeline-notifications"
  resource    = aws_codepipeline.main.arn
  detail_type = "FULL"

  event_type_ids = [
    "codepipeline-pipeline-pipeline-execution-failed",
    "codepipeline-pipeline-pipeline-execution-succeeded",
    "codepipeline-pipeline-manual-approval-needed"
  ]

  # Substitua pelo ARN do seu SNS topic
  # target {
  #   address = "arn:aws:sns:us-east-1:123456789012:meu-topic"
  # }

  tags = {
    Name = "${var.project_name}-${var.environment}-pipeline-notifications"
  }
}
