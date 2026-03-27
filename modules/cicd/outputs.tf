output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "pipeline_name" {
  value = aws_codepipeline.main.name
}

output "github_connection_arn" {
  value       = aws_codestarconnections_connection.github.arn
  description = "ATENÇÃO: Autenticar esta conexão manualmente no Console AWS > CodePipeline > Settings > Connections"
}
