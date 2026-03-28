#!/bin/bash
# Full deployment script for GitHub Runners on AWS
# Usage: ./scripts/deploy.sh [--auto-approve]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

AUTO_APPROVE=""
if [[ "$1" == "--auto-approve" ]]; then
    AUTO_APPROVE="-auto-approve"
fi

echo "=================================================="
echo "GitHub Runners on AWS - Deployment"
echo "=================================================="
echo ""

# -----------------------------------------------------------------------------
# Step 1: Check prerequisites
# -----------------------------------------------------------------------------
echo -e "${YELLOW}1. Checking prerequisites...${NC}"

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: terraform not found${NC}"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: aws CLI not found${NC}"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl not found${NC}"
    exit 1
fi

# Check terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}Error: terraform.tfvars not found${NC}"
    echo "Run ./scripts/generate-tfvars.sh first"
    exit 1
fi

# Check for placeholder values
if grep -q "REPLACE_WITH" terraform.tfvars; then
    echo -e "${RED}Error: terraform.tfvars contains placeholder values${NC}"
    echo "Update the REPLACE_WITH values before deploying"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites OK${NC}"

# -----------------------------------------------------------------------------
# Step 2: Download Lambda packages
# -----------------------------------------------------------------------------
echo ""
echo -e "${YELLOW}2. Downloading Lambda packages...${NC}"

./scripts/download-lambdas.sh

echo -e "${GREEN}✓ Lambda packages ready${NC}"

# -----------------------------------------------------------------------------
# Step 3: Terraform init
# -----------------------------------------------------------------------------
echo ""
echo -e "${YELLOW}3. Initializing Terraform...${NC}"

terraform init -upgrade

echo -e "${GREEN}✓ Terraform initialized${NC}"

# -----------------------------------------------------------------------------
# Step 4: Terraform plan
# -----------------------------------------------------------------------------
echo ""
echo -e "${YELLOW}4. Planning infrastructure...${NC}"

terraform plan -out=tfplan

# -----------------------------------------------------------------------------
# Step 5: Terraform apply
# -----------------------------------------------------------------------------
echo ""
echo -e "${YELLOW}5. Applying infrastructure...${NC}"

if [ -n "$AUTO_APPROVE" ]; then
    terraform apply tfplan
else
    read -p "Apply this plan? (yes/no): " CONFIRM
    if [[ "$CONFIRM" == "yes" ]]; then
        terraform apply tfplan
    else
        echo "Cancelled."
        rm -f tfplan
        exit 0
    fi
fi

rm -f tfplan

echo -e "${GREEN}✓ Infrastructure deployed${NC}"

# -----------------------------------------------------------------------------
# Step 6: Post-apply configuration
# -----------------------------------------------------------------------------
echo ""
echo -e "${YELLOW}6. Post-apply configuration...${NC}"

./scripts/post-apply.sh

echo ""
echo "=================================================="
echo -e "${GREEN}Deployment complete!${NC}"
echo "=================================================="
