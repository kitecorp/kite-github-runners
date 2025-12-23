#!/bin/bash
# Post-apply script: Get webhook URL and configure GitHub App
# Usage: ./scripts/post-apply.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "=================================================="
echo "GitHub Runners - Post Apply Configuration"
echo "=================================================="
echo ""

# -----------------------------------------------------------------------------
# Get Webhook URL from Terraform
# -----------------------------------------------------------------------------
echo -e "${YELLOW}1. Getting Webhook URL from Terraform...${NC}"
echo ""

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: terraform command not found${NC}"
    exit 1
fi

# Check if terraform state exists
if [ ! -f "terraform.tfstate" ] && [ ! -d ".terraform" ]; then
    echo -e "${RED}Error: No terraform state found. Run 'terraform apply' first.${NC}"
    exit 1
fi

WEBHOOK_URL=$(terraform output -raw webhook_endpoint 2>/dev/null || echo "")

if [ -z "$WEBHOOK_URL" ]; then
    echo -e "${RED}Error: Could not get webhook_endpoint from terraform output.${NC}"
    echo "Make sure 'terraform apply' completed successfully."
    exit 1
fi

echo -e "${GREEN}Webhook URL:${NC}"
echo ""
echo -e "  ${CYAN}${WEBHOOK_URL}${NC}"
echo ""

# Copy to clipboard if possible
if command -v pbcopy &> /dev/null; then
    echo "$WEBHOOK_URL" | pbcopy
    echo -e "${GREEN}✓ Copied to clipboard (macOS)${NC}"
elif command -v xclip &> /dev/null; then
    echo "$WEBHOOK_URL" | xclip -selection clipboard
    echo -e "${GREEN}✓ Copied to clipboard (Linux)${NC}"
fi

# -----------------------------------------------------------------------------
# Show GitHub App Settings URL
# -----------------------------------------------------------------------------
echo ""
echo -e "${YELLOW}2. Configure GitHub App Webhook${NC}"
echo ""
echo "Open your GitHub App settings:"
echo ""
echo -e "  Personal: ${CYAN}https://github.com/settings/apps${NC}"
echo -e "  Organization: ${CYAN}https://github.com/organizations/YOUR_ORG/settings/apps${NC}"
echo ""

# Try to open browser
read -p "Open GitHub Apps settings in browser? (Y/n): " OPEN_BROWSER
OPEN_BROWSER="${OPEN_BROWSER:-Y}"

if [[ "$OPEN_BROWSER" =~ ^[Yy]$ ]]; then
    if command -v open &> /dev/null; then
        open "https://github.com/settings/apps"
    elif command -v xdg-open &> /dev/null; then
        xdg-open "https://github.com/settings/apps"
    fi
fi

# -----------------------------------------------------------------------------
# Show Instructions with Screenshots
# -----------------------------------------------------------------------------
echo ""
echo -e "${YELLOW}3. Update Webhook Settings${NC}"
echo ""
echo "In your GitHub App settings page:"
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│  GitHub App Settings                                                │"
echo "├─────────────────────────────────────────────────────────────────────┤"
echo "│                                                                     │"
echo "│  General                                                            │"
echo "│  ├── Basic information                                              │"
echo "│  ├── Display information                                            │"
echo "│  └── ${GREEN}Webhook${NC}  ◄── Click here                                      │"
echo "│                                                                     │"
echo "│  ┌─────────────────────────────────────────────────────────────┐    │"
echo "│  │  Webhook                                                    │    │"
echo "│  │                                                             │    │"
echo "│  │  ${GREEN}☑ Active${NC}                                                │    │"
echo "│  │                                                             │    │"
echo "│  │  Webhook URL:                                               │    │"
echo "│  │  ┌─────────────────────────────────────────────────────┐    │    │"
echo "│  │  │ ${CYAN}${WEBHOOK_URL}${NC}"
echo "│  │  └─────────────────────────────────────────────────────┘    │    │"
echo "│  │                                                             │    │"
echo "│  │  Webhook secret:                                            │    │"
echo "│  │  ┌─────────────────────────────────────────────────────┐    │    │"
echo "│  │  │ (use the secret from terraform.tfvars)              │    │    │"
echo "│  │  └─────────────────────────────────────────────────────┘    │    │"
echo "│  │                                                             │    │"
echo "│  │  SSL verification: ${GREEN}☑ Enable${NC}                              │    │"
echo "│  │                                                             │    │"
echo "│  └─────────────────────────────────────────────────────────────┘    │"
echo "│                                                                     │"
echo "│  Permissions & events                                               │"
echo "│  └── Subscribe to events: ${GREEN}☑ Workflow job${NC}                        │"
echo "│                                                                     │"
echo "└─────────────────────────────────────────────────────────────────────┘"
echo ""

# -----------------------------------------------------------------------------
# Webhook Secret Reminder
# -----------------------------------------------------------------------------
echo -e "${YELLOW}4. Webhook Secret${NC}"
echo ""
echo "Your webhook secret is in terraform.tfvars:"
echo ""
WEBHOOK_SECRET=$(grep 'github_webhook_secret' terraform.tfvars 2>/dev/null | cut -d'"' -f2 || echo "")
if [ -n "$WEBHOOK_SECRET" ]; then
    echo -e "  ${CYAN}${WEBHOOK_SECRET}${NC}"
else
    echo "  (check terraform.tfvars for github_webhook_secret)"
fi
echo ""

# -----------------------------------------------------------------------------
# Install App
# -----------------------------------------------------------------------------
echo -e "${YELLOW}5. Install the GitHub App${NC}"
echo ""
echo "After configuring the webhook, install the app to your organization/repos:"
echo ""
echo "  1. Go to your GitHub App settings"
echo "  2. Click 'Install App' in the left sidebar"
echo "  3. Select the organization or account"
echo "  4. Choose 'All repositories' or select specific repos"
echo ""

# -----------------------------------------------------------------------------
# Verify Setup
# -----------------------------------------------------------------------------
echo -e "${YELLOW}6. Verify Setup${NC}"
echo ""
echo "Test by triggering a workflow in a repo where the app is installed."
echo "Use these labels in your workflow:"
echo ""
echo -e "  ${CYAN}runs-on: [self-hosted, linux, x64]${NC}      # Linux x64"
echo -e "  ${CYAN}runs-on: [self-hosted, linux, arm64]${NC}    # Linux ARM64 (Graviton)"
echo -e "  ${CYAN}runs-on: [self-hosted, windows, x64]${NC}    # Windows x64"
echo ""

echo "=================================================="
echo -e "${GREEN}Setup complete!${NC}"
echo ""
echo "Useful commands:"
echo "  terraform output              # Show all outputs"
echo "  terraform output webhook_endpoint  # Show webhook URL"
echo "=================================================="
