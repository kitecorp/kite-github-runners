################################################################################
# GitHub Actions Self-Hosted Runners on AWS
# Supports: Linux x64, Linux arm64, Windows x64
# Note: macOS is NOT supported by this module due to EC2 Mac Dedicated Host requirements
#
# IMPORTANT: Run ./scripts/download-lambdas.sh before terraform apply
################################################################################

################################################################################
# Multi-Runner Module
################################################################################
module "github_runner" {
  source  = "github-aws-runners/github-runner/aws//modules/multi-runner"
  version = "7.0.0"

  aws_region = var.aws_region
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  prefix = var.prefix

  github_app = {
    key_base64     = var.github_app_key_base64
    id             = var.github_app_id
    webhook_secret = var.github_webhook_secret
  }

  # Lambda zip files - download with: ./scripts/download-lambdas.sh
  webhook_lambda_zip                = "${path.module}/webhook.zip"
  runners_lambda_zip                = "${path.module}/runners.zip"
  runner_binaries_syncer_lambda_zip = "${path.module}/runner-binaries-syncer.zip"

  multi_runner_config = {
    #---------------------------------------------------------------------------
    # Linux x64 Runner Configuration
    #---------------------------------------------------------------------------
    "linux-x64" = {
      matcherConfig = {
        labelMatchers = [["self-hosted", "linux", "x64"]]
        exactMatch    = true
      }
      fifo = true

      runner_config = {
        runner_os           = "linux"
        runner_architecture = "x64"
        runner_name_prefix  = "linux-x64_"
        runner_extra_labels = var.runner_extra_labels

        # Organization or repository level runners
        enable_organization_runners = var.enable_organization_runners

        # Instance configuration - m5/c5 families for x64
        instance_types        = ["m5ad.large", "m5a.large", "m5d.large", "c5.large", "c5a.large"]
        runners_maximum_count = var.linux_x64_max_runners

        # AMI configuration - Use AWS SSM parameter for latest Amazon Linux 2023
        ami_id_ssm_parameter_name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"

        # Spot instances for cost savings
        instance_allocation_strategy  = var.enable_spot_instances ? "price-capacity-optimized" : "lowest-price"
        instance_target_capacity_type = var.enable_spot_instances ? "spot" : "on-demand"

        # Runner settings
        enable_ephemeral_runners = true
        enable_ssm_on_runners    = true

        # Scaling configuration
        scale_down_schedule_expression  = "cron(* * * * ? *)"
        minimum_running_time_in_minutes = 5

        # Block device configuration
        block_device_mappings = [{
          device_name           = "/dev/xvda"
          delete_on_termination = true
          volume_size           = 50
          volume_type           = "gp3"
          encrypted             = true
          iops                  = 3000
          throughput            = 125
        }]
      }
    }

    #---------------------------------------------------------------------------
    # Linux arm64 (Graviton) Runner Configuration
    #---------------------------------------------------------------------------
    "linux-arm64" = {
      matcherConfig = {
        labelMatchers = [["self-hosted", "linux", "arm64"]]
        exactMatch    = true
      }
      fifo = true

      runner_config = {
        runner_os           = "linux"
        runner_architecture = "arm64"
        runner_name_prefix  = "linux-arm64_"
        runner_extra_labels = var.runner_extra_labels

        # Organization or repository level runners
        enable_organization_runners = var.enable_organization_runners

        # Instance configuration - Graviton instances (t4g/c6g/m6g families)
        instance_types        = ["t4g.large", "c6g.large", "m6g.large", "c7g.large", "m7g.large"]
        runners_maximum_count = var.linux_arm64_max_runners

        # AMI configuration - Use AWS SSM parameter for latest Amazon Linux 2023 ARM64
        ami_id_ssm_parameter_name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-arm64"

        # Spot instances for cost savings
        instance_allocation_strategy  = var.enable_spot_instances ? "price-capacity-optimized" : "lowest-price"
        instance_target_capacity_type = var.enable_spot_instances ? "spot" : "on-demand"

        # Runner settings
        enable_ephemeral_runners = true
        enable_ssm_on_runners    = true

        # Scaling configuration
        scale_down_schedule_expression  = "cron(* * * * ? *)"
        minimum_running_time_in_minutes = 5

        # Block device configuration
        block_device_mappings = [{
          device_name           = "/dev/xvda"
          delete_on_termination = true
          volume_size           = 50
          volume_type           = "gp3"
          encrypted             = true
          iops                  = 3000
          throughput            = 125
        }]
      }
    }

    #---------------------------------------------------------------------------
    # Windows x64 Runner Configuration
    #---------------------------------------------------------------------------
    "windows-x64" = {
      matcherConfig = {
        labelMatchers = [["self-hosted", "windows", "x64"]]
        exactMatch    = true
      }
      fifo = true

      runner_config = {
        runner_os           = "windows"
        runner_architecture = "x64"
        runner_name_prefix  = "windows-x64_"
        runner_extra_labels = var.runner_extra_labels

        # Organization or repository level runners
        enable_organization_runners = var.enable_organization_runners

        # Instance configuration - Windows requires more resources
        instance_types        = ["m5.large", "c5.large", "m5a.large", "c5a.large"]
        runners_maximum_count = var.windows_x64_max_runners

        # Windows boot time is longer
        runner_boot_time_in_minutes = 20

        # AMI configuration - Use AWS SSM parameter for Windows Server 2022
        ami_id_ssm_parameter_name = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"

        # On-demand for Windows (spot less reliable for Windows)
        instance_allocation_strategy  = "lowest-price"
        instance_target_capacity_type = "on-demand"

        # Runner settings
        enable_ephemeral_runners = true
        enable_ssm_on_runners    = true

        # Scaling configuration
        scale_down_schedule_expression  = "cron(* * * * ? *)"
        minimum_running_time_in_minutes = 10

        # Block device configuration - Windows needs more storage
        block_device_mappings = [{
          device_name           = "/dev/sda1"
          delete_on_termination = true
          volume_size           = 100
          volume_type           = "gp3"
          encrypted             = true
          iops                  = 3000
          throughput            = 125
        }]
      }
    }
  }

  # Logging configuration
  logging_retention_in_days = 30
  logging_kms_key_id        = null

  # Tags
  tags = {
    Project = "github-runners"
  }
}
