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

# Auto-detect repository from GitHub context if not provided
REPOSITORY="${INPUT_REPOSITORY:-https://github.com/${GITHUB_REPOSITORY}}"
export LISSTO_REPOSITORY="${REPOSITORY}"

# Auto-detect branch from GitHub context
BRANCH="${INPUT_BRANCH:-${GITHUB_REF_NAME}}"

# Auto-detect author from GitHub actor
AUTHOR="${INPUT_AUTHOR:-${GITHUB_ACTOR}}"

# Compose file path
COMPOSE_FILE="${INPUT_COMPOSE_FILE:-docker-compose.yml}"

# Validate compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "::error::Compose file not found: $COMPOSE_FILE"
    exit 1
fi

echo "Creating blueprint from: $COMPOSE_FILE"
echo "Repository: $REPOSITORY"
echo "Branch: $BRANCH"
echo "Author: $AUTHOR"

# Build command
CMD="lissto blueprint create \"${COMPOSE_FILE}\" --output json"
[ -n "$BRANCH" ] && CMD="$CMD --branch \"${BRANCH}\""
[ -n "$AUTHOR" ] && CMD="$CMD --author \"${AUTHOR}\""

# Run command and capture output
OUTPUT=$(eval $CMD)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo "::error::Failed to create blueprint"
    echo "$OUTPUT"
    exit $EXIT_CODE
fi

# Parse and set outputs
BLUEPRINT_ID=$(echo "$OUTPUT" | jq -r '.id')

if [ -z "$BLUEPRINT_ID" ] || [ "$BLUEPRINT_ID" = "null" ]; then
    echo "::error::Failed to parse blueprint ID from response"
    echo "$OUTPUT"
    exit 1
fi

echo "blueprint-id=${BLUEPRINT_ID}" >> $GITHUB_OUTPUT

echo "✅ Blueprint created successfully!"
echo "   ID: ${BLUEPRINT_ID}"
