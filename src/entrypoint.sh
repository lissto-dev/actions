#!/bin/bash
set -e

# --- Helpers ---
require() {
    for var in "$@"; do
        [ -z "${!var}" ] && { echo "::error::${var} is required"; exit 1; }
    done
}
output() { echo "$1=$2" >> "$GITHUB_OUTPUT"; }

# --- CLI Version Override ---
if [ -n "$INPUT_CLI_VERSION" ]; then
    echo "Installing Lissto CLI ${INPUT_CLI_VERSION}..."
    curl -sL "https://github.com/lissto-dev/cli/releases/download/${INPUT_CLI_VERSION}/lissto_linux_amd64.tar.gz" | tar xz -C /usr/local/bin
    lissto --version
fi

# --- Init ---
export LISSTO_API_KEY="$INPUT_API_KEY" LISSTO_API_URL="$INPUT_API_URL"
require INPUT_API_KEY INPUT_API_URL

BRANCH="${INPUT_BRANCH:-${GITHUB_REF_NAME}}"
AUTHOR="${GITHUB_ACTOR}"

# --- Actions ---
action_blueprint_create() {
    echo "📦 Creating blueprint..."
    
    CMD="lissto blueprint create --output json"
    [ -n "$INPUT_COMPOSE_FILE" ] && CMD="$CMD $INPUT_COMPOSE_FILE"
    [ -n "$BRANCH" ] && CMD="$CMD --branch $BRANCH"
    [ -n "$AUTHOR" ] && CMD="$CMD --author $AUTHOR"
    
    result=$(eval $CMD)
    
    id=$(echo "$result" | jq -r '.id')
    [ -z "$id" ] || [ "$id" = "null" ] && { echo "::error::Failed to parse blueprint ID"; echo "$result"; exit 1; }
    
    output "blueprint-id" "$id"
    echo "✅ Blueprint created: $id"
}

action_deploy() {
    BLUEPRINT_ID="${INPUT_BLUEPRINT_ID}"
    
    if [ -z "$BLUEPRINT_ID" ]; then
        echo "📦 Creating blueprint..."
        CMD="lissto blueprint create --output json"
        [ -n "$INPUT_COMPOSE_FILE" ] && CMD="$CMD $INPUT_COMPOSE_FILE"
        [ -n "$BRANCH" ] && CMD="$CMD --branch $BRANCH"
        [ -n "$AUTHOR" ] && CMD="$CMD --author $AUTHOR"
        
        bp_result=$(eval $CMD)
        BLUEPRINT_ID=$(echo "$bp_result" | jq -r '.id')
        [ -z "$BLUEPRINT_ID" ] || [ "$BLUEPRINT_ID" = "null" ] && { echo "::error::Failed to create blueprint"; exit 1; }
        echo "✅ Blueprint: $BLUEPRINT_ID"
    fi
    
    echo "🚀 Deploying stack..."
    CMD="lissto create stack --blueprint $BLUEPRINT_ID --non-interactive --output json"
    [ -n "$BRANCH" ] && CMD="$CMD --branch $BRANCH"
    
    result=$(eval $CMD)
    
    stack_id=$(echo "$result" | jq -r '.stack_id')
    stack_url=$(echo "$result" | jq -r '.exposed[0].url // empty')
    
    output "blueprint-id" "$BLUEPRINT_ID"
    output "stack-id" "$stack_id"
    [ -n "$stack_url" ] && output "stack-url" "$stack_url"
    
    echo "✅ Deployed! Stack: $stack_id"
    [ -n "$stack_url" ] && echo "   URL: $stack_url"
}

action_update() {
    echo "🔄 Updating stack..."
    
    CMD="lissto update --non-interactive --yes --output json"
    [ -n "$BRANCH" ] && CMD="$CMD --branch $BRANCH"
    
    result=$(eval $CMD)
    
    stack_id=$(echo "$result" | jq -r '.stack_id // .stack_name')
    status=$(echo "$result" | jq -r '.status')
    services=$(echo "$result" | jq -r '.updated_services | join(",") // empty')
    
    output "stack-id" "$stack_id"
    output "status" "$status"
    [ -n "$services" ] && output "updated-services" "$services"
    
    [ "$status" = "no-changes" ] && echo "ℹ️  Already up to date" || echo "✅ Updated: $stack_id"
}

# --- Dispatch ---
case "$LISSTO_ACTION" in
    blueprint-create) action_blueprint_create ;;
    deploy) action_deploy ;;
    update) action_update ;;
    *) echo "::error::Unknown action: $LISSTO_ACTION"; exit 1 ;;
esac
