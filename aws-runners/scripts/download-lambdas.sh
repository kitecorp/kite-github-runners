#!/bin/bash
# Download Lambda zip files from GitHub releases
# Run this before terraform apply

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAMBDA_DIR="${SCRIPT_DIR}/.."
VERSION="v7.0.0"

echo "Downloading Lambda packages (${VERSION})..."
echo ""

cd "$LAMBDA_DIR"

# Lambda files to download
LAMBDAS=("webhook" "runners" "runner-binaries-syncer")

for lambda in "${LAMBDAS[@]}"; do
    FILE="${lambda}.zip"
    URL="https://github.com/github-aws-runners/terraform-aws-github-runner/releases/download/${VERSION}/${FILE}"

    if [ -f "$FILE" ]; then
        echo "✓ ${FILE} already exists, skipping"
    else
        echo "Downloading ${FILE}..."
        curl -sL -o "$FILE" "$URL"

        if [ -f "$FILE" ]; then
            echo "✓ Downloaded ${FILE}"
        else
            echo "✗ Failed to download ${FILE}"
            exit 1
        fi
    fi
done

echo ""
echo "All Lambda packages downloaded to: ${LAMBDA_DIR}"
ls -la *.zip
echo ""
echo "Now run: terraform apply"
