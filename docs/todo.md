# TODO

## Pending Features

- [ ] Add custom AMI build with Packer for pre-installed tools
- [ ] Add Ubuntu runner configuration as alternative to Amazon Linux
- [ ] Consider macOS support via separate Dedicated Host module
- [ ] Add monitoring and alerting (CloudWatch dashboards)
- [ ] Add cost estimation documentation

## Skipped Features

### macOS Runners
**Reason:** EC2 Mac instances require Dedicated Hosts with 24-hour minimum allocation. This doesn't fit the auto-scaling model of the terraform-aws-github-runner module. Consider:
1. Using GitHub-hosted macOS runners (`macos-latest`, `macos-14`)
2. Separate Terraform module for persistent Mac Dedicated Hosts
3. Third-party macOS CI services (MacStadium, Codemagic)
