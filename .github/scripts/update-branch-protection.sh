#!/usr/bin/env bash
# Update branch protection rules to require new validation workflow

set -euo pipefail

REPO="${GITHUB_REPOSITORY:-sob/home-ops}"
BRANCH="main"

# This script should be run with a GitHub token that has admin access
# Example: GITHUB_TOKEN=ghp_xxx ./update-branch-protection.sh

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    echo "Error: GITHUB_TOKEN environment variable not set"
    exit 1
fi

echo "Updating branch protection for ${REPO}:${BRANCH}"

# Update branch protection to require the new status check
curl -X PUT \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  "https://api.github.com/repos/${REPO}/branches/${BRANCH}/protection" \
  -d '{
    "required_status_checks": {
      "strict": true,
      "checks": [
        {
          "context": "Validation Success",
          "app_id": null
        }
      ]
    },
    "enforce_admins": false,
    "required_pull_request_reviews": null,
    "restrictions": null,
    "allow_force_pushes": false,
    "allow_deletions": false,
    "block_creations": false,
    "required_conversation_resolution": false,
    "lock_branch": false,
    "allow_fork_syncing": true
  }'

echo "Branch protection updated successfully"