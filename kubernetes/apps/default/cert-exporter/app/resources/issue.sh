#!/bin/bash
# Exit if DOMAIN is not set
if [ -z "$DOMAIN" ]; then
  echo "Error: DOMAIN environment variable is not set"
  exit 1
fi

# Set Cloudflare credentials
export CF_Key="${CF_API_KEY}"
export CF_Email="${ACME_EMAIL}"

echo "Issuing new certificate for ${DOMAIN}..."
acme.sh --issue \
  -d ${DOMAIN} \
  --dns dns_cloudflare \
  --server letsencrypt

if [ $? -eq 0 ]; then
  echo "Certificate issued successfully."
  /scripts/deploy-cert.sh
else
  echo "Failed to issue certificate"
  exit 1
fi
