output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_arn" {
  value = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_ca_data" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

output "node_group_name" {
  value = aws_eks_node_group.default.node_group_name
}

output "oidc_provider_arn" {
  value = var.create_oidc_provider ? aws_iam_openid_connect_provider.eks[0].arn : null
}

output "bedrock_irsa_role_arn" {
  value = var.enable_bedrock_irsa && var.create_oidc_provider ? aws_iam_role.bedrock_irsa[0].arn : null
}
