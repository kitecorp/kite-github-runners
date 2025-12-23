#!/bin/bash
# Complete setup script for GitHub Runners on AWS
# This is the only script you need to run!
#
# Usage: ./setup.sh [--org YOUR_ORG]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Parse arguments
GITHUB_ORG=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --org)
            GITHUB_ORG="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║         GitHub Self-Hosted Runners on AWS - Setup                ║"
echo "║                                                                  ║"
echo "║  Platforms: Linux x64, Linux arm64 (Graviton), Windows x64       ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# STEP 1: Prerequisites check
# =============================================================================
echo -e "${YELLOW}━━━ Step 1/7: Checking prerequisites ━━━${NC}"
echo ""

MISSING=""
command -v terraform &>/dev/null || MISSING="${MISSING}terraform "
command -v aws &>/dev/null || MISSING="${MISSING}aws "
command -v curl &>/dev/null || MISSING="${MISSING}curl "
command -v openssl &>/dev/null || MISSING="${MISSING}openssl "

if [ -n "$MISSING" ]; then
    echo -e "${RED}Missing required tools: ${MISSING}${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites installed${NC}"
echo ""

# =============================================================================
# STEP 2: AWS Profile Selection
# =============================================================================
echo -e "${YELLOW}━━━ Step 2/7: AWS Configuration ━━━${NC}"
echo ""

CURRENT_PROFILE="${AWS_PROFILE:-default}"
echo "Available AWS profiles:"
aws configure list-profiles 2>/dev/null | while read profile; do
    if [ "$profile" == "$CURRENT_PROFILE" ]; then
        echo -e "  ${GREEN}● ${profile}${NC} (current)"
    else
        echo "  ○ ${profile}"
    fi
done
echo ""

read -p "AWS profile to use [${CURRENT_PROFILE}]: " SELECTED_PROFILE
export AWS_PROFILE="${SELECTED_PROFILE:-$CURRENT_PROFILE}"

echo ""
echo "Verifying credentials..."
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "${RED}Error: Cannot authenticate with AWS profile '${AWS_PROFILE}'${NC}"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
echo -e "${GREEN}✓ AWS Account: ${ACCOUNT_ID}${NC}"

# Get region
AWS_REGION=$(aws configure get region 2>/dev/null || echo "")
if [ -z "$AWS_REGION" ]; then
    read -p "AWS Region [us-east-1]: " AWS_REGION
    AWS_REGION="${AWS_REGION:-us-east-1}"
fi
echo -e "${GREEN}✓ Region: ${AWS_REGION}${NC}"

# Get VPC
echo ""
echo "Fetching VPCs..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "None")

if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
    echo "Available VPCs:"
    aws ec2 describe-vpcs --query "Vpcs[*].[VpcId,Tags[?Key=='Name'].Value|[0]]" --output table
    read -p "Enter VPC ID: " VPC_ID
fi
echo -e "${GREEN}✓ VPC: ${VPC_ID}${NC}"

# Get subnets
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}" --query "Subnets[*].SubnetId" --output json 2>/dev/null)
echo -e "${GREEN}✓ Subnets: ${SUBNET_IDS}${NC}"

echo ""

# =============================================================================
# STEP 3: GitHub App Setup
# =============================================================================
echo -e "${YELLOW}━━━ Step 3/7: GitHub App Configuration ━━━${NC}"
echo ""

# Generate webhook secret
WEBHOOK_SECRET=$(openssl rand -hex 32)

# Determine GitHub App URL
if [ -n "$GITHUB_ORG" ]; then
    GITHUB_APP_URL="https://github.com/organizations/${GITHUB_ORG}/settings/apps/new"
    echo "Organization: ${GITHUB_ORG}"
else
    GITHUB_APP_URL="https://github.com/settings/apps/new"
    echo "Personal account (use --org YOUR_ORG for organization)"
fi

echo ""
echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│  Create a GitHub App with these settings:                       │${NC}"
echo -e "${CYAN}├─────────────────────────────────────────────────────────────────┤${NC}"
echo -e "${CYAN}│                                                                 │${NC}"
echo -e "${CYAN}│  App name: ${GREEN}github-runners-aws${CYAN}                                  │${NC}"
echo -e "${CYAN}│  Homepage: ${GREEN}https://github.com${CYAN}                                  │${NC}"
echo -e "${CYAN}│  Webhook URL: ${YELLOW}(leave empty for now)${CYAN}                           │${NC}"
echo -e "${CYAN}│  Webhook secret: ${GREEN}${WEBHOOK_SECRET:0:20}...${CYAN}  │${NC}"
echo -e "${CYAN}│                                                                 │${NC}"
echo -e "${CYAN}│  Permissions:                                                   │${NC}"
echo -e "${CYAN}│    Repository:                                                  │${NC}"
echo -e "${CYAN}│      • Actions: Read-only                                       │${NC}"
echo -e "${CYAN}│      • Administration: Read & write                             │${NC}"
echo -e "${CYAN}│      • Checks: Read-only                                        │${NC}"
echo -e "${CYAN}│      • Metadata: Read-only                                      │${NC}"
echo -e "${CYAN}│    Organization:                                                │${NC}"
echo -e "${CYAN}│      • Self-hosted runners: Read & write                        │${NC}"
echo -e "${CYAN}│                                                                 │${NC}"
echo -e "${CYAN}│  Subscribe to events:                                           │${NC}"
echo -e "${CYAN}│      • Workflow job                                             │${NC}"
echo -e "${CYAN}│                                                                 │${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────────────────────────┘${NC}"
echo ""

echo "Opening browser to create GitHub App..."
if command -v open &>/dev/null; then
    open "$GITHUB_APP_URL"
elif command -v xdg-open &>/dev/null; then
    xdg-open "$GITHUB_APP_URL"
fi

echo ""
read -p "Press Enter after creating the GitHub App..."

echo ""
read -p "Enter GitHub App ID: " GITHUB_APP_ID

while [ -z "$GITHUB_APP_ID" ]; do
    echo -e "${RED}App ID is required${NC}"
    read -p "Enter GitHub App ID: " GITHUB_APP_ID
done

echo ""
echo "Now generate a private key in your GitHub App settings."
echo "(Scroll down to 'Private keys' and click 'Generate a private key')"
echo ""
read -p "Enter path to downloaded .pem file: " PEM_PATH

while [ ! -f "$PEM_PATH" ]; do
    echo -e "${RED}File not found: ${PEM_PATH}${NC}"
    read -p "Enter path to downloaded .pem file: " PEM_PATH
done

# Base64 encode the private key
if [[ "$OSTYPE" == "darwin"* ]]; then
    GITHUB_APP_KEY_BASE64=$(base64 -i "$PEM_PATH" | tr -d '\n')
else
    GITHUB_APP_KEY_BASE64=$(base64 -w 0 "$PEM_PATH")
fi

echo -e "${GREEN}✓ Private key encoded${NC}"
echo ""

# =============================================================================
# STEP 4: Generate terraform.tfvars
# =============================================================================
echo -e "${YELLOW}━━━ Step 4/7: Generating Terraform configuration ━━━${NC}"
echo ""

cat > terraform.tfvars << EOF
# Generated by setup.sh on $(date)
aws_region  = "${AWS_REGION}"
environment = "prod"

vpc_id     = "${VPC_ID}"
subnet_ids = ${SUBNET_IDS}

github_app_id         = "${GITHUB_APP_ID}"
github_app_key_base64 = "${GITHUB_APP_KEY_BASE64}"
github_webhook_secret = "${WEBHOOK_SECRET}"

prefix = "github-runner"

linux_x64_max_runners   = 5
linux_arm64_max_runners = 5
windows_x64_max_runners = 3

enable_spot_instances = true
enable_organization_runners = true

runner_extra_labels = []
EOF

echo -e "${GREEN}✓ terraform.tfvars created${NC}"
echo ""

# =============================================================================
# STEP 5: Download Lambda packages
# =============================================================================
echo -e "${YELLOW}━━━ Step 5/7: Downloading Lambda packages ━━━${NC}"
echo ""

VERSION="v7.0.0"
LAMBDAS=("webhook" "runners" "runner-binaries-syncer")

for lambda in "${LAMBDAS[@]}"; do
    FILE="${lambda}.zip"
    if [ ! -f "$FILE" ]; then
        echo "Downloading ${FILE}..."
        curl -sL -o "$FILE" "https://github.com/github-aws-runners/terraform-aws-github-runner/releases/download/${VERSION}/${FILE}"
    fi
    echo -e "${GREEN}✓ ${FILE}${NC}"
done
echo ""

# =============================================================================
# STEP 6: Terraform deploy
# =============================================================================
echo -e "${YELLOW}━━━ Step 6/7: Deploying infrastructure ━━━${NC}"
echo ""

echo "Initializing Terraform..."
terraform init -upgrade

echo ""
echo "Planning..."
terraform plan -out=tfplan

echo ""
read -p "Deploy this infrastructure? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo "Cancelled."
    rm -f tfplan
    exit 0
fi

echo ""
echo "Applying (this may take 5-10 minutes)..."
terraform apply tfplan
rm -f tfplan

echo -e "${GREEN}✓ Infrastructure deployed${NC}"
echo ""

# =============================================================================
# STEP 7: Configure webhook
# =============================================================================
echo -e "${YELLOW}━━━ Step 7/7: Configure GitHub App webhook ━━━${NC}"
echo ""

WEBHOOK_URL=$(terraform output -raw webhook_endpoint 2>/dev/null)

echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│  Update your GitHub App webhook settings:                       │${NC}"
echo -e "${CYAN}├─────────────────────────────────────────────────────────────────┤${NC}"
echo -e "${CYAN}│                                                                 │${NC}"
echo -e "${CYAN}│  1. Go to your GitHub App settings                              │${NC}"
echo -e "${CYAN}│  2. Click 'Webhook' in the left sidebar                         │${NC}"
echo -e "${CYAN}│  3. Check 'Active'                                              │${NC}"
echo -e "${CYAN}│  4. Set Webhook URL to:                                         │${NC}"
echo -e "${CYAN}│                                                                 │${NC}"
echo -e "${GREEN}│     ${WEBHOOK_URL}${NC}"
echo -e "${CYAN}│                                                                 │${NC}"
echo -e "${CYAN}│  5. Webhook secret is already set                               │${NC}"
echo -e "${CYAN}│  6. Enable SSL verification                                     │${NC}"
echo -e "${CYAN}│  7. Save changes                                                │${NC}"
echo -e "${CYAN}│                                                                 │${NC}"
echo -e "${CYAN}│  Then install the app:                                          │${NC}"
echo -e "${CYAN}│  • Click 'Install App' in left sidebar                          │${NC}"
echo -e "${CYAN}│  • Select your organization/account                             │${NC}"
echo -e "${CYAN}│  • Choose repos (All or specific)                               │${NC}"
echo -e "${CYAN}│                                                                 │${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────────────────────────┘${NC}"
echo ""

# Copy webhook URL to clipboard
if command -v pbcopy &>/dev/null; then
    echo "$WEBHOOK_URL" | pbcopy
    echo -e "${GREEN}✓ Webhook URL copied to clipboard${NC}"
fi

# Open GitHub App settings
if [ -n "$GITHUB_ORG" ]; then
    APP_URL="https://github.com/organizations/${GITHUB_ORG}/settings/apps"
else
    APP_URL="https://github.com/settings/apps"
fi

echo ""
read -p "Open GitHub App settings? (Y/n): " OPEN_BROWSER
OPEN_BROWSER="${OPEN_BROWSER:-Y}"

if [[ "$OPEN_BROWSER" =~ ^[Yy]$ ]]; then
    if command -v open &>/dev/null; then
        open "$APP_URL"
    elif command -v xdg-open &>/dev/null; then
        xdg-open "$APP_URL"
    fi
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo -e "║  ${GREEN}Setup complete!${NC}                                                 ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║                                                                  ║"
echo "║  Use these labels in your GitHub Actions workflows:              ║"
echo "║                                                                  ║"
echo -e "║    ${CYAN}runs-on: [self-hosted, linux, x64]${NC}      # Linux Intel        ║"
echo -e "║    ${CYAN}runs-on: [self-hosted, linux, arm64]${NC}    # Linux Graviton     ║"
echo -e "║    ${CYAN}runs-on: [self-hosted, windows, x64]${NC}    # Windows            ║"
echo "║                                                                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
