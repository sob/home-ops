#!/bin/bash

set -e

# Determine container runtime
if command -v podman >/dev/null 2>&1; then
    CONTAINER_CMD="podman"
else
    CONTAINER_CMD="docker"
fi

BUCKET=$1
OLD_NAME=$2
NEW_NAME=$3

if [ -z "$BUCKET" ] || [ -z "$OLD_NAME" ] || [ -z "$NEW_NAME" ]; then
    echo "Error: Bucket, old and new folder names are required"
    exit 1
fi

# Get credentials from 1Password
CLOUDFLARE_R2_ACCOUNT_ID=$(op read "op://STONEHEDGES/cloudflare/CLOUDFLARE_R2_ACCOUNT_ID")
AWS_ACCESS_KEY_ID=$(op read "op://STONEHEDGES/cloudflare/AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY=$(op read "op://STONEHEDGES/cloudflare/AWS_SECRET_ACCESS_KEY")

echo "Renaming from ${BUCKET}/${OLD_NAME} to ${BUCKET}/${NEW_NAME}..."
$CONTAINER_CMD run --rm \
    -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
    -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
    amazon/aws-cli --endpoint-url "https://${CLOUDFLARE_R2_ACCOUNT_ID}.r2.cloudflarestorage.com" \
    s3 mv --copy-props none "s3://${BUCKET}/${OLD_NAME}" "s3://${BUCKET}/${NEW_NAME}" --recursive

echo "Folder rename complete"
