output "webhook_endpoint" {
  description = "API Gateway endpoint for GitHub webhooks"
  value       = module.github_runner.webhook.endpoint
}

output "webhook_secret_arn" {
  description = "ARN of the webhook secret in Secrets Manager"
  value       = module.github_runner.webhook.secret_arn
  sensitive   = true
}

output "runners_lambda_function_names" {
  description = "Names of the Lambda functions for runner management"
  value = {
    scale_up   = module.github_runner.runners.scale_up.function_name
    scale_down = module.github_runner.runners.scale_down.function_name
  }
}

output "runners_role_arns" {
  description = "IAM role ARNs for the runners"
  value       = module.github_runner.runners.role_arn
}

output "runners_security_group_ids" {
  description = "Security group IDs for the runners"
  value       = module.github_runner.runners.security_group_id
}
