variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "kubernetes_version" {
  type    = string
  default = "1.30"
}

variable "endpoint_private_access" {
  type    = bool
  default = true
}

variable "endpoint_public_access" {
  type    = bool
  default = true
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 5
}

variable "create_oidc_provider" {
  description = "Create IAM OIDC provider for IRSA"
  type        = bool
  default     = true
}

variable "enable_bedrock_irsa" {
  description = "Create an IRSA role to allow pods to call Amazon Bedrock"
  type        = bool
  default     = false
}

variable "bedrock_namespace" {
  description = "Kubernetes namespace for the service account that uses Bedrock"
  type        = string
  default     = "app"
}

variable "bedrock_service_account" {
  description = "Kubernetes service account name that uses Bedrock"
  type        = string
  default     = "bedrock-client"
}

variable "bedrock_allowed_actions" {
  description = "Bedrock IAM actions allowed for the IRSA role"
  type        = list(string)
  default = [
    "bedrock:InvokeModel",
    "bedrock:InvokeModelWithResponseStream",
    "bedrock:ListFoundationModels"
  ]
}

variable "allowed_bedrock_model_arns" {
  description = "Allowed model ARNs for Bedrock access"
  type        = list(string)
  default     = ["*"]
}
