#!/bin/bash

set -e

# Determine container runtime
if command -v podman >/dev/null 2>&1; then
    CONTAINER_CMD="podman"
else
    CONTAINER_CMD="docker"
fi

OLD_NAME=$1
NEW_NAME=$2

if [ -z "$OLD_NAME" ] || [ -z "$NEW_NAME" ]; then
    echo "Error: Both old and new folder names are required"
    exit 1
fi

# Get credentials from 1Password
CLOUDFLARE_R2_ACCOUNT_ID=$(op read "op://STONEHEDGES/cloudflare/CLOUDFLARE_R2_ACCOUNT_ID")
AWS_ACCESS_KEY_ID=$(op read "op://STONEHEDGES/cloudflare/AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY=$(op read "op://STONEHEDGES/cloudflare/AWS_SECRET_ACCESS_KEY")

echo "Renaming folder from ${OLD_NAME} to ${NEW_NAME}..."
$CONTAINER_CMD run --rm \
    -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
    -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
    amazon/aws-cli --endpoint-url "https://${CLOUDFLARE_R2_ACCOUNT_ID}.r2.cloudflarestorage.com" \
    s3 mv --copy-props none "s3://stone-volsync/${OLD_NAME}" "s3://stone-volsync/${NEW_NAME}" --recursive

echo "Folder rename complete"
