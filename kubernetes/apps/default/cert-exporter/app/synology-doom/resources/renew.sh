#!/bin/bash

if [ -z "$DOMAIN" ]; then
    echo "Error: DOMAIN environment variable is not set"
    exit 1
fi

export CF_Key="${CF_API_KEY}"
export CF_Email="${ACME_EMAIL}"

# Install the kubectl deployer if not already configured
if [ -d "/root/.acme.sh/${DOMAIN}" ]; then
    acme.sh --install-cert -d ${DOMAIN} \
        --cert-file /root/.acme.sh/${DOMAIN}/${DOMAIN}.cer \
        --key-file /root/.acme.sh/${DOMAIN}/${DOMAIN}.key
fi

echo "Running acme.sh cron renewal check..."
acme.sh --cron --home "/root/.acme.sh"
