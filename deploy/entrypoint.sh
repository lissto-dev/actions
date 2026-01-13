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

# Auto-detect repository from GitHub context if not provided
REPOSITORY="${INPUT_REPOSITORY:-https://github.com/${GITHUB_REPOSITORY}}"
export LISSTO_REPOSITORY="${REPOSITORY}"

# Compose file path
COMPOSE_FILE="${INPUT_COMPOSE_FILE:-docker-compose.yml}"

# Step 1: Get or create blueprint
BLUEPRINT_ID="${INPUT_BLUEPRINT_ID}"

if [ -z "$BLUEPRINT_ID" ]; then
    # Validate compose file exists
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo "::error::Compose file not found: $COMPOSE_FILE"
        exit 1
    fi

    echo "📦 Creating blueprint from: $COMPOSE_FILE"
    
    # Build blueprint create command
    BP_CMD="lissto blueprint create \"${COMPOSE_FILE}\" --output json"
    
    # Add branch from input or GitHub context
    BRANCH="${INPUT_BRANCH:-${GITHUB_REF_NAME}}"
    [ -n "$BRANCH" ] && BP_CMD="$BP_CMD --branch \"${BRANCH}\""
    
    # Add author from GitHub actor
    [ -n "$GITHUB_ACTOR" ] && BP_CMD="$BP_CMD --author \"${GITHUB_ACTOR}\""
    
    BP_OUTPUT=$(eval $BP_CMD)
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -ne 0 ]; then
        echo "::error::Failed to create blueprint"
        echo "$BP_OUTPUT"
        exit $EXIT_CODE
    fi
    
    BLUEPRINT_ID=$(echo "$BP_OUTPUT" | jq -r '.id')
    
    if [ -z "$BLUEPRINT_ID" ] || [ "$BLUEPRINT_ID" = "null" ]; then
        echo "::error::Failed to parse blueprint ID from response"
        echo "$BP_OUTPUT"
        exit 1
    fi
    
    echo "✅ Blueprint created: $BLUEPRINT_ID"
else
    echo "📦 Using existing blueprint: $BLUEPRINT_ID"
fi

# Step 2: Create stack
echo "🚀 Creating stack in environment: ${INPUT_ENVIRONMENT}"

STACK_CMD="lissto create stack --blueprint \"${BLUEPRINT_ID}\" --env \"${INPUT_ENVIRONMENT}\" --non-interactive --output json"

# Add version specifiers if provided
[ -n "$INPUT_BRANCH" ] && STACK_CMD="$STACK_CMD --branch \"${INPUT_BRANCH}\""
[ -n "$INPUT_TAG" ] && STACK_CMD="$STACK_CMD --tag \"${INPUT_TAG}\""
[ -n "$INPUT_COMMIT" ] && STACK_CMD="$STACK_CMD --commit \"${INPUT_COMMIT}\""

STACK_OUTPUT=$(eval $STACK_CMD)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo "::error::Failed to create stack"
    echo "$STACK_OUTPUT"
    exit $EXIT_CODE
fi

# Parse outputs
STACK_ID=$(echo "$STACK_OUTPUT" | jq -r '.stack_id')
STACK_URL=$(echo "$STACK_OUTPUT" | jq -r '.exposed[0].url // empty')

if [ -z "$STACK_ID" ] || [ "$STACK_ID" = "null" ]; then
    echo "::error::Failed to parse stack ID from response"
    echo "$STACK_OUTPUT"
    exit 1
fi

# Set outputs
echo "blueprint-id=${BLUEPRINT_ID}" >> $GITHUB_OUTPUT
echo "stack-id=${STACK_ID}" >> $GITHUB_OUTPUT
[ -n "$STACK_URL" ] && echo "stack-url=${STACK_URL}" >> $GITHUB_OUTPUT

echo ""
echo "✅ Stack deployed successfully!"
echo "   Blueprint ID: ${BLUEPRINT_ID}"
echo "   Stack ID: ${STACK_ID}"
[ -n "$STACK_URL" ] && echo "   URL: ${STACK_URL}"
