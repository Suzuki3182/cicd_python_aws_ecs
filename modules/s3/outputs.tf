output "bucket_name" {
  value = aws_s3_bucket.main.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.main.arn
}

output "bucket_id" {
  value = aws_s3_bucket.main.id
}

output "kms_key_arn" {
  value = aws_kms_key.s3.arn
}
