#!/bin/bash
set -e

# Install Lissto CLI
install_cli() {
    local version="${INPUT_CLI_VERSION:-latest}"
    
    if [ "$version" = "latest" ]; then
        version=$(curl -s https://api.github.com/repos/lissto-dev/cli/releases/latest | jq -r .tag_name)
    fi
    
    echo "Installing Lissto CLI version: $version"
    curl -sL "https://github.com/lissto-dev/cli/releases/download/${version}/lissto_linux_amd64.tar.gz" | tar xz -C /usr/local/bin
    
    if ! command -v lissto &> /dev/null; then
        echo "::error::Failed to install Lissto CLI"
        exit 1
    fi
}

# Install CLI
install_cli

# Export auth environment variables (CLI reads these)
export LISSTO_API_KEY="${INPUT_API_KEY}"
export LISSTO_API_URL="${INPUT_API_URL}"

# Validate required inputs
if [ -z "$LISSTO_API_KEY" ] || [ -z "$LISSTO_API_URL" ]; then
    echo "::error::api-key and api-url are required"
    exit 1
fi

if [ -z "$INPUT_ENVIRONMENT" ]; then
    echo "::error::environment is required"
    exit 1
fi

echo "🔄 Updating stack in environment: ${INPUT_ENVIRONMENT}"

# Build update command
UPDATE_CMD="lissto update --env \"${INPUT_ENVIRONMENT}\" --non-interactive --yes --output json"

# Add optional stack name
[ -n "$INPUT_STACK" ] && UPDATE_CMD="$UPDATE_CMD --stack \"${INPUT_STACK}\""

# Add version specifiers if provided
[ -n "$INPUT_BRANCH" ] && UPDATE_CMD="$UPDATE_CMD --branch \"${INPUT_BRANCH}\""
[ -n "$INPUT_TAG" ] && UPDATE_CMD="$UPDATE_CMD --tag \"${INPUT_TAG}\""
[ -n "$INPUT_COMMIT" ] && UPDATE_CMD="$UPDATE_CMD --commit \"${INPUT_COMMIT}\""

OUTPUT=$(eval $UPDATE_CMD)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo "::error::Failed to update stack"
    echo "$OUTPUT"
    exit $EXIT_CODE
fi

# Parse outputs
STACK_ID=$(echo "$OUTPUT" | jq -r '.stack_id // .stack_name')
UPDATED_SERVICES=$(echo "$OUTPUT" | jq -r '.updated_services | join(",")')
STATUS=$(echo "$OUTPUT" | jq -r '.status')

# Set outputs
echo "stack-id=${STACK_ID}" >> $GITHUB_OUTPUT
echo "updated-services=${UPDATED_SERVICES}" >> $GITHUB_OUTPUT
echo "status=${STATUS}" >> $GITHUB_OUTPUT

echo ""
if [ "$STATUS" = "no-changes" ]; then
    echo "ℹ️  No new images found - stack is up to date"
else
    echo "✅ Stack updated successfully!"
    echo "   Stack ID: ${STACK_ID}"
    if [ -n "$UPDATED_SERVICES" ]; then
        echo "   Updated services: ${UPDATED_SERVICES}"
    fi
fi
