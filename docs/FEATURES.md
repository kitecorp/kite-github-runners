# GitHub Runners on AWS - Features

## Multi-Platform Self-Hosted Runners

Terraform configuration for deploying scalable GitHub Actions self-hosted runners on AWS.

### Supported Platforms

| Platform | Architecture | Status | Instance Types |
|----------|-------------|--------|----------------|
| Linux | x64 | ✅ Supported | m5ad, m5a, m5d, c5, c5a |
| Linux | arm64 | ✅ Supported | t4g, c6g, m6g, c7g, m7g (Graviton) |
| Windows | x64 | ✅ Supported | m5, c5, m5a, c5a |
| macOS | x64 | ❌ Not supported | Requires Dedicated Hosts |
| macOS | arm64 | ❌ Not supported | Requires Dedicated Hosts |

### Features

#### Ephemeral Runners
- Runners are created on-demand when jobs are queued
- Automatically terminated after job completion
- Prevents build contamination between jobs

#### Auto-Scaling
- Scales up based on GitHub webhook events
- Scales down to zero when no jobs are running
- Configurable maximum runner counts per platform

#### Cost Optimization
- Spot instance support for Linux runners
- On-demand for Windows (more reliable)
- Scale to zero when idle

#### Security
- IMDSv2 required (http_tokens = required)
- Encrypted EBS volumes
- SSM Session Manager access (no SSH keys needed)
- Runs in private subnets

### Usage in GitHub Actions

```yaml
jobs:
  build-linux-x64:
    runs-on: [self-hosted, linux, x64]
    steps:
      - uses: actions/checkout@v4
      # ... your build steps

  build-linux-arm64:
    runs-on: [self-hosted, linux, arm64]
    steps:
      - uses: actions/checkout@v4
      # ... your build steps

  build-windows:
    runs-on: [self-hosted, windows, x64]
    steps:
      - uses: actions/checkout@v4
      # ... your build steps
```

### Configuration

See `aws-runners/terraform.tfvars.example` for configuration options.

**Reference:** `aws-runners/main.tf`
