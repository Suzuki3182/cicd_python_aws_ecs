# ============================================================
# Módulo S3 - Bucket seguro com políticas e ciclo de vida
# ============================================================

# -----------------------------------------------------------
# Bucket Principal
# -----------------------------------------------------------
#checkov:skip=CKV_AWS_144:Cross-region replication not required for this workload
resource "aws_s3_bucket" "main" {
  bucket = var.bucket_name

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Name = var.bucket_name
  }
}

# -----------------------------------------------------------
# Bloqueia todo acesso público (NUNCA deixe público por padrão)
# -----------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------
# Versionamento (permite recuperar versões antigas de objetos)
# -----------------------------------------------------------
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Disabled"
  }
}

# -----------------------------------------------------------
# Criptografia SSE-S3 em repouso (padrão AWS)
# Para mais segurança, use SSE-KMS com chave gerenciada
# -----------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms" # Usa KMS para criptografia
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true # Reduz custo de chamadas KMS
  }
}

# -----------------------------------------------------------
# KMS Key para o S3
# -----------------------------------------------------------
data "aws_caller_identity" "current" {}

resource "aws_kms_key" "s3" {
  description             = "KMS para criptografia do S3 ${var.bucket_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.bucket_name}-kms"
  }
}

# -----------------------------------------------------------
# Política do Bucket
# -----------------------------------------------------------
resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.id
  policy = data.aws_iam_policy_document.s3_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.main]
}

data "aws_iam_policy_document" "s3_bucket" {
  # Nega acesso sem criptografia (força HTTPS)
  statement {
    sid    = "DenyNonSSLRequests"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.main.arn,
      "${aws_s3_bucket.main.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Permite acesso da conta atual
  statement {
    sid    = "AllowAccountAccess"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.main.arn,
      "${aws_s3_bucket.main.arn}/*",
    ]
  }
}

data "aws_caller_identity" "current" {}

# -----------------------------------------------------------
# Política de ciclo de vida (reduz custos de armazenamento)
# -----------------------------------------------------------
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  # Regra para objetos gerais
  rule {
    id     = "general-lifecycle"
    status = "Enabled"

    filter {}

    # Move para S3-IA após 30 dias (60% mais barato que S3 Standard)
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Move para Glacier após 90 dias (para arquivamento)
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Deleta após 365 dias (ajuste conforme requisitos)
    expiration {
      days = 365
    }
  }

  # Regra para versões antigas de objetos
  rule {
    id     = "old-versions-cleanup"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  # Limpa uploads multipart incompletos (evita custo oculto)
  rule {
    id     = "cleanup-incomplete-multipart"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# -----------------------------------------------------------
# Logging de acesso ao bucket
# -----------------------------------------------------------
#checkov:skip=CKV_AWS_144:Cross-region replication not required for S3 access log buckets
resource "aws_s3_bucket" "access_logs" {
  bucket = "${var.bucket_name}-access-logs"

  tags = {
    Name    = "${var.bucket_name}-access-logs"
    Purpose = "S3 Access Logs"
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket                  = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "access-logs-expiry"
    status = "Enabled"
    filter {}
    expiration {
      days = 90
    }
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_notification" "access_logs" {
  bucket      = aws_s3_bucket.access_logs.id
  eventbridge = true
}

resource "aws_s3_bucket_logging" "main" {
  bucket        = aws_s3_bucket.main.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "access-logs/"
}

# -----------------------------------------------------------
# Notificações S3 -> CloudWatch (opcional)
# -----------------------------------------------------------
resource "aws_s3_bucket_notification" "main" {
  bucket      = aws_s3_bucket.main.id
  eventbridge = true
}
