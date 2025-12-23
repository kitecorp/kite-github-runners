output "webhook_endpoint" {
  description = "API Gateway endpoint for GitHub webhooks - configure this in your GitHub App"
  value       = module.github_runner.webhook.endpoint
}

output "webhook_lambda" {
  description = "Webhook Lambda function details"
  value = {
    function_name = module.github_runner.webhook.lambda.function_name
    log_group     = module.github_runner.webhook.lambda_log_group.name
  }
}

output "ssm_parameters" {
  description = "SSM parameters created by the module"
  value       = module.github_runner.ssm_parameters
}

output "runners" {
  description = "Runner configurations"
  value       = keys(module.github_runner.runners_map)
}
