################################################################################
# GitHub Actions Self-Hosted Runners on AWS
# Supports: Linux x64, Linux arm64, Windows x64
# Note: macOS is NOT supported by this module due to EC2 Mac Dedicated Host requirements
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

  # Webhook configuration
  webhook_lambda_zip = null
  webhook_lambda_apigateway_access_log_settings = {
    destination_arn = null
    format          = null
  }

  # Enable Organization runners (set to false for repository-level runners)
  enable_organization_runners = true

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

        # Instance configuration - m5/c5 families for x64
        instance_types        = ["m5ad.large", "m5a.large", "m5d.large", "c5.large", "c5a.large"]
        runners_maximum_count = var.linux_x64_max_runners

        # AMI configuration - Amazon Linux 2023 x64
        ami = {
          filter = {
            name  = ["al2023-ami-kernel-6.1-x86_64"]
            state = ["available"]
          }
          owners = ["amazon"]
        }

        # Spot instances for cost savings
        instance_allocation_strategy  = var.enable_spot_instances ? "price-capacity-optimized" : "lowest-price"
        instance_target_capacity_type = var.enable_spot_instances ? "spot" : "on-demand"

        # Runner settings
        enable_ephemeral_runners      = true
        enable_ssm_on_runners         = true
        enable_runner_binaries_syncer = true

        # Scaling configuration
        scale_down_schedule_expression  = "cron(* * * * ? *)"
        minimum_running_time_in_minutes = 5

        # Instance metadata options
        instance_metadata_options = {
          http_endpoint               = "enabled"
          http_tokens                 = "required"
          http_put_response_hop_limit = 2
        }

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

        # Instance configuration - Graviton instances (t4g/c6g/m6g families)
        instance_types        = ["t4g.large", "c6g.large", "m6g.large", "c7g.large", "m7g.large"]
        runners_maximum_count = var.linux_arm64_max_runners

        # AMI configuration - Amazon Linux 2023 arm64
        ami = {
          filter = {
            name  = ["al2023-ami-kernel-6.1-arm64"]
            state = ["available"]
          }
          owners = ["amazon"]
        }

        # Spot instances for cost savings
        instance_allocation_strategy  = var.enable_spot_instances ? "price-capacity-optimized" : "lowest-price"
        instance_target_capacity_type = var.enable_spot_instances ? "spot" : "on-demand"

        # Runner settings
        enable_ephemeral_runners      = true
        enable_ssm_on_runners         = true
        enable_runner_binaries_syncer = true

        # Scaling configuration
        scale_down_schedule_expression  = "cron(* * * * ? *)"
        minimum_running_time_in_minutes = 5

        # Instance metadata options
        instance_metadata_options = {
          http_endpoint               = "enabled"
          http_tokens                 = "required"
          http_put_response_hop_limit = 2
        }

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

        # Instance configuration - Windows requires more resources
        instance_types        = ["m5.large", "c5.large", "m5a.large", "c5a.large"]
        runners_maximum_count = var.windows_x64_max_runners

        # Windows boot time is longer
        runner_boot_time_in_minutes = 20

        # AMI configuration - Windows Server 2022
        ami = {
          filter = {
            name  = ["Windows_Server-2022-English-Full-ECS_Optimized-*"]
            state = ["available"]
          }
          owners = ["amazon"]
        }

        # On-demand for Windows (spot less reliable for Windows)
        instance_allocation_strategy  = "lowest-price"
        instance_target_capacity_type = "on-demand"

        # Runner settings
        enable_ephemeral_runners      = true
        enable_ssm_on_runners         = true
        enable_runner_binaries_syncer = true

        # Scaling configuration
        scale_down_schedule_expression  = "cron(* * * * ? *)"
        minimum_running_time_in_minutes = 10

        # Instance metadata options
        instance_metadata_options = {
          http_endpoint               = "enabled"
          http_tokens                 = "required"
          http_put_response_hop_limit = 2
        }

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
