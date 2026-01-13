#!/bin/bash
set -e

# --- Helpers ---
require() {
    for var in "$@"; do
        [ -z "${!var}" ] && { echo "::error::${var} is required"; exit 1; }
    done
}
output() { echo "$1=$2" >> "$GITHUB_OUTPUT"; }

# --- Init ---
export LISSTO_API_KEY="$INPUT_API_KEY" LISSTO_API_URL="$INPUT_API_URL"
require INPUT_API_KEY INPUT_API_URL

BRANCH="${INPUT_BRANCH:-${GITHUB_REF_NAME}}"
COMPOSE="${INPUT_COMPOSE_FILE:-docker-compose.yml}"

# --- Actions ---
action_blueprint_create() {
    [ ! -f "$COMPOSE" ] && { echo "::error::Compose file not found: $COMPOSE"; exit 1; }
    
    echo "📦 Creating blueprint from $COMPOSE"
    result=$(lissto blueprint create "$COMPOSE" --output json \
        ${BRANCH:+--branch "$BRANCH"} \
        ${GITHUB_ACTOR:+--author "$GITHUB_ACTOR"})
    
    id=$(echo "$result" | jq -r '.id')
    [ -z "$id" ] || [ "$id" = "null" ] && { echo "::error::Failed to parse blueprint ID"; echo "$result"; exit 1; }
    
    output "blueprint-id" "$id"
    echo "✅ Blueprint created: $id"
}

action_deploy() {
    require INPUT_ENVIRONMENT
    
    BLUEPRINT_ID="${INPUT_BLUEPRINT_ID}"
    
    if [ -z "$BLUEPRINT_ID" ]; then
        [ ! -f "$COMPOSE" ] && { echo "::error::Compose file not found: $COMPOSE"; exit 1; }
        echo "📦 Creating blueprint from $COMPOSE"
        bp_result=$(lissto blueprint create "$COMPOSE" --output json \
            ${BRANCH:+--branch "$BRANCH"} \
            ${GITHUB_ACTOR:+--author "$GITHUB_ACTOR"})
        BLUEPRINT_ID=$(echo "$bp_result" | jq -r '.id')
        [ -z "$BLUEPRINT_ID" ] || [ "$BLUEPRINT_ID" = "null" ] && { echo "::error::Failed to create blueprint"; exit 1; }
        echo "✅ Blueprint: $BLUEPRINT_ID"
    fi
    
    echo "🚀 Deploying to ${INPUT_ENVIRONMENT}"
    result=$(lissto create stack --blueprint "$BLUEPRINT_ID" --env "$INPUT_ENVIRONMENT" --non-interactive --output json \
        ${INPUT_BRANCH:+--branch "$INPUT_BRANCH"} \
        ${INPUT_TAG:+--tag "$INPUT_TAG"} \
        ${INPUT_COMMIT:+--commit "$INPUT_COMMIT"})
    
    stack_id=$(echo "$result" | jq -r '.stack_id')
    stack_url=$(echo "$result" | jq -r '.exposed[0].url // empty')
    
    output "blueprint-id" "$BLUEPRINT_ID"
    output "stack-id" "$stack_id"
    [ -n "$stack_url" ] && output "stack-url" "$stack_url"
    
    echo "✅ Deployed! Stack: $stack_id"
    [ -n "$stack_url" ] && echo "   URL: $stack_url"
}

action_update() {
    require INPUT_ENVIRONMENT
    
    echo "🔄 Updating stack in ${INPUT_ENVIRONMENT}"
    result=$(lissto update --env "$INPUT_ENVIRONMENT" --non-interactive --yes --output json \
        ${INPUT_STACK:+--stack "$INPUT_STACK"} \
        ${INPUT_BRANCH:+--branch "$INPUT_BRANCH"} \
        ${INPUT_TAG:+--tag "$INPUT_TAG"} \
        ${INPUT_COMMIT:+--commit "$INPUT_COMMIT"})
    
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
