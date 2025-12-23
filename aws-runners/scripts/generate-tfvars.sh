#!/bin/bash
# Generate terraform.tfvars values for GitHub Runners on AWS
# Usage: ./scripts/generate-tfvars.sh [--org YOUR_ORG]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_FILE="${SCRIPT_DIR}/../terraform.tfvars"

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

echo "=================================================="
echo "GitHub Runners - Terraform Variables Generator"
echo "=================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# AWS Profile Selection
# -----------------------------------------------------------------------------
echo -e "${YELLOW}1. AWS Profile Selection${NC}"
echo "------------------------"

# Get current profile
CURRENT_PROFILE="${AWS_PROFILE:-default}"
echo "Current AWS profile: ${CURRENT_PROFILE}"
echo ""

# List available profiles
echo "Available profiles:"
aws configure list-profiles 2>/dev/null | while read profile; do
    if [ "$profile" == "$CURRENT_PROFILE" ]; then
        echo -e "  ${GREEN}* ${profile}${NC} (current)"
    else
        echo "    ${profile}"
    fi
done
echo ""

read -p "Enter AWS profile to use (or press Enter for '${CURRENT_PROFILE}'): " SELECTED_PROFILE

if [ -n "$SELECTED_PROFILE" ]; then
    export AWS_PROFILE="$SELECTED_PROFILE"
    echo -e "Using profile: ${GREEN}${AWS_PROFILE}${NC}"
else
    export AWS_PROFILE="$CURRENT_PROFILE"
    echo -e "Using profile: ${GREEN}${AWS_PROFILE}${NC}"
fi

# Verify credentials work
echo ""
echo "Verifying AWS credentials..."
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "${RED}Error: Unable to authenticate with AWS profile '${AWS_PROFILE}'${NC}"
    echo "Please check your credentials and try again."
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
echo -e "AWS Account: ${GREEN}${ACCOUNT_ID}${NC}"

# -----------------------------------------------------------------------------
# AWS Configuration
# -----------------------------------------------------------------------------
echo ""
echo -e "${YELLOW}2. AWS Configuration${NC}"
echo "-------------------"

# Get region from profile
AWS_REGION=$(aws configure get region 2>/dev/null || echo "")
if [ -z "$AWS_REGION" ]; then
    echo "No default region configured for this profile."
    read -p "Enter AWS region (default: us-east-1): " AWS_REGION
    AWS_REGION="${AWS_REGION:-us-east-1}"
fi
echo -e "aws_region = \"${GREEN}${AWS_REGION}${NC}\""

# Get default VPC
echo ""
echo "Fetching default VPC..."
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=is-default,Values=true" \
    --query "Vpcs[0].VpcId" \
    --output text 2>/dev/null || echo "")

if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
    echo -e "${YELLOW}No default VPC found. Listing all VPCs:${NC}"
    aws ec2 describe-vpcs --query "Vpcs[*].[VpcId,Tags[?Key=='Name'].Value|[0]]" --output table
    echo ""
    VPC_ID="REPLACE_WITH_YOUR_VPC_ID"
    echo -e "${RED}Set vpc_id manually in terraform.tfvars${NC}"
else
    echo -e "vpc_id = \"${GREEN}${VPC_ID}${NC}\""
fi

# Get subnets
echo ""
echo "Fetching subnets..."
if [ "$VPC_ID" != "REPLACE_WITH_YOUR_VPC_ID" ]; then
    SUBNET_IDS=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --query "Subnets[*].SubnetId" \
        --output json 2>/dev/null || echo '["REPLACE_WITH_SUBNET_IDS"]')
    echo -e "subnet_ids = ${GREEN}${SUBNET_IDS}${NC}"
else
    SUBNET_IDS='["REPLACE_WITH_SUBNET_IDS"]'
    echo "Set subnet_ids manually after selecting VPC"
fi

# -----------------------------------------------------------------------------
# GitHub Webhook Secret
# -----------------------------------------------------------------------------
echo ""
echo -e "${YELLOW}3. GitHub Webhook Secret${NC}"
echo "------------------------"
WEBHOOK_SECRET=$(openssl rand -hex 32)
echo -e "github_webhook_secret = \"${GREEN}${WEBHOOK_SECRET}${NC}\""

# -----------------------------------------------------------------------------
# GitHub App Creation
# -----------------------------------------------------------------------------
echo ""
echo -e "${YELLOW}4. GitHub App Creation${NC}"
echo "----------------------"

# Determine GitHub App URL
if [ -n "$GITHUB_ORG" ]; then
    GITHUB_APP_URL="https://github.com/organizations/${GITHUB_ORG}/settings/apps/new"
    echo "Creating app for organization: ${GITHUB_ORG}"
else
    GITHUB_APP_URL="https://github.com/settings/apps/new"
    echo "Creating personal GitHub App (use --org YOUR_ORG for organization)"
fi

echo ""
echo -e "${BLUE}Required App Settings:${NC}"
echo "  - App name: github-runners-aws"
echo "  - Homepage URL: https://github.com"
echo "  - Webhook: Will configure after terraform apply"
echo "  - Webhook secret: ${WEBHOOK_SECRET}"
echo ""
echo -e "${BLUE}Required Permissions:${NC}"
echo "  Repository: Actions (Read), Administration (Read/Write), Checks (Read), Metadata (Read)"
echo "  Organization: Self-hosted runners (Read/Write)"
echo ""
echo -e "${BLUE}Subscribe to events:${NC} Workflow job"
echo ""

# Open browser to create GitHub App
echo -e "${YELLOW}Opening browser to create GitHub App...${NC}"
echo -e "URL: ${GREEN}${GITHUB_APP_URL}${NC}"
echo ""

# Try to open browser (works on macOS, Linux with xdg-open, or WSL)
if command -v open &> /dev/null; then
    open "$GITHUB_APP_URL"
elif command -v xdg-open &> /dev/null; then
    xdg-open "$GITHUB_APP_URL"
elif command -v wslview &> /dev/null; then
    wslview "$GITHUB_APP_URL"
else
    echo -e "${RED}Could not open browser automatically.${NC}"
    echo "Please open this URL manually: ${GITHUB_APP_URL}"
fi

# -----------------------------------------------------------------------------
# Wait for user to create app and get App ID
# -----------------------------------------------------------------------------
echo ""
echo -e "${YELLOW}5. Enter GitHub App ID${NC}"
echo "----------------------"
echo "After creating the app, the App ID is shown at the top of the app's settings page."
echo ""
read -p "Enter your GitHub App ID (or press Enter to skip): " GITHUB_APP_ID

if [ -z "$GITHUB_APP_ID" ]; then
    GITHUB_APP_ID="REPLACE_WITH_APP_ID"
    echo -e "${RED}Skipped. Update github_app_id in terraform.tfvars later.${NC}"
else
    echo -e "github_app_id = \"${GREEN}${GITHUB_APP_ID}${NC}\""
fi

# -----------------------------------------------------------------------------
# GitHub App Private Key
# -----------------------------------------------------------------------------
echo ""
echo -e "${YELLOW}6. GitHub App Private Key${NC}"
echo "-------------------------"
echo "In your GitHub App settings, scroll to 'Private keys' and click 'Generate a private key'."
echo "This will download a .pem file."
echo ""
read -p "Enter path to your private key .pem file (or press Enter to skip): " PEM_PATH

if [ -z "$PEM_PATH" ]; then
    GITHUB_APP_KEY_BASE64="REPLACE_WITH_BASE64_KEY"
    echo -e "${RED}Skipped. Run this command later to get the base64 key:${NC}"
    echo -e "  ${GREEN}base64 -i /path/to/your-app.private-key.pem | tr -d '\\n'${NC}"
elif [ -f "$PEM_PATH" ]; then
    # Base64 encode the private key
    if [[ "$OSTYPE" == "darwin"* ]]; then
        GITHUB_APP_KEY_BASE64=$(base64 -i "$PEM_PATH" | tr -d '\n')
    else
        GITHUB_APP_KEY_BASE64=$(base64 -w 0 "$PEM_PATH")
    fi
    echo -e "${GREEN}Private key encoded successfully.${NC}"
    echo "github_app_key_base64 = \"${GITHUB_APP_KEY_BASE64:0:50}...[truncated]\""
else
    GITHUB_APP_KEY_BASE64="REPLACE_WITH_BASE64_KEY"
    echo -e "${RED}File not found: ${PEM_PATH}${NC}"
    echo "Update github_app_key_base64 in terraform.tfvars later."
fi

# -----------------------------------------------------------------------------
# Write terraform.tfvars
# -----------------------------------------------------------------------------
cat > "${OUTPUT_FILE}" << EOF
# Generated by generate-tfvars.sh on $(date)
# GitHub Runners on AWS - Terraform Variables

aws_region  = "${AWS_REGION}"
environment = "prod"

# AWS Networking
vpc_id     = "${VPC_ID}"
subnet_ids = ${SUBNET_IDS}

# GitHub App Configuration
# App settings page: https://github.com/settings/apps (or org settings)
github_app_id         = "${GITHUB_APP_ID}"
github_app_key_base64 = "${GITHUB_APP_KEY_BASE64}"
github_webhook_secret = "${WEBHOOK_SECRET}"

# Runner Configuration
prefix = "github-runner"

linux_x64_max_runners   = 5
linux_arm64_max_runners = 5
windows_x64_max_runners = 3

enable_spot_instances = true

runner_extra_labels = []
EOF

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "=================================================="
echo -e "${GREEN}Written to: ${OUTPUT_FILE}${NC}"
echo "=================================================="
echo ""
cat "${OUTPUT_FILE}"
echo ""
echo "=================================================="

# Check what still needs to be done
TODOS=()
if [ "$VPC_ID" == "REPLACE_WITH_YOUR_VPC_ID" ]; then
    TODOS+=("Update vpc_id")
fi
if [[ "$SUBNET_IDS" == *"REPLACE"* ]]; then
    TODOS+=("Update subnet_ids")
fi
if [ "$GITHUB_APP_ID" == "REPLACE_WITH_APP_ID" ]; then
    TODOS+=("Update github_app_id")
fi
if [ "$GITHUB_APP_KEY_BASE64" == "REPLACE_WITH_BASE64_KEY" ]; then
    TODOS+=("Update github_app_key_base64 (run: base64 -i your-key.pem | tr -d '\\n')")
fi

if [ ${#TODOS[@]} -eq 0 ]; then
    echo -e "${GREEN}All values configured! Next steps:${NC}"
    echo "  1. terraform init"
    echo "  2. terraform plan"
    echo "  3. terraform apply"
    echo "  4. Run: ./scripts/post-apply.sh"
else
    echo -e "${YELLOW}TODO - Update these in terraform.tfvars:${NC}"
    for todo in "${TODOS[@]}"; do
        echo "  - ${todo}"
    done
    echo ""
    echo "Then run:"
    echo "  1. terraform init"
    echo "  2. terraform plan"
    echo "  3. terraform apply"
    echo "  4. Run: ./scripts/post-apply.sh"
fi
echo "=================================================="
