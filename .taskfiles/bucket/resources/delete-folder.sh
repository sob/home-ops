#!/bin/bash

set -e

# Determine container runtime
if command -v podman >/dev/null 2>&1; then
    CONTAINER_CMD="podman"
else
    CONTAINER_CMD="docker"
fi

BUCKET=$1
FOLDER=$2

if [ -z "$FOLDER" ]; then
    echo "Error: Folder name is required"
    exit 1
fi

# Get credentials directly
CLOUDFLARE_R2_ACCOUNT_ID=$(op read "op://STONEHEDGES/cloudflare/CLOUDFLARE_R2_ACCOUNT_ID")
AWS_ACCESS_KEY_ID=$(op read "op://STONEHEDGES/cloudflare/AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY=$(op read "op://STONEHEDGES/cloudflare/AWS_SECRET_ACCESS_KEY")

echo "Deleting folder and contents: ${FOLDER}"
$CONTAINER_CMD run --rm \
    -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
    -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
    amazon/aws-cli --endpoint-url "https://${CLOUDFLARE_R2_ACCOUNT_ID}.r2.cloudflarestorage.com" \
    s3 rm "s3://${BUCKET}/${FOLDER}" --recursive

echo "Deletion complete"
