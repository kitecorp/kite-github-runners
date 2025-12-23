variable "aws_region" {
  description = "AWS region to deploy the runners"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "vpc_id" {
  description = "VPC ID where runners will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for runner instances"
  type        = list(string)
}

variable "github_app_id" {
  description = "GitHub App ID for authentication"
  type        = string
  sensitive   = true
}

variable "github_app_key_base64" {
  description = "Base64 encoded GitHub App private key"
  type        = string
  sensitive   = true
}

variable "github_webhook_secret" {
  description = "GitHub webhook secret for validating webhook payloads"
  type        = string
  sensitive   = true
}

variable "prefix" {
  description = "Prefix for all resources"
  type        = string
  default     = "github-runner"
}

# Runner configuration
variable "linux_x64_max_runners" {
  description = "Maximum number of Linux x64 runners"
  type        = number
  default     = 5
}

variable "linux_arm64_max_runners" {
  description = "Maximum number of Linux arm64 runners"
  type        = number
  default     = 5
}

variable "windows_x64_max_runners" {
  description = "Maximum number of Windows x64 runners"
  type        = number
  default     = 3
}

variable "enable_spot_instances" {
  description = "Enable spot instances for cost savings (Linux only)"
  type        = bool
  default     = true
}

variable "runner_extra_labels" {
  description = "Additional labels to add to all runners"
  type        = list(string)
  default     = []
}

variable "enable_organization_runners" {
  description = "Register runners at organization level (true) or repository level (false)"
  type        = bool
  default     = true
}
