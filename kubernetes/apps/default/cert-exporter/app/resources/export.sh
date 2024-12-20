#!/usr/bin/env sh

# Default and required environment variables
ACMESH=${ACMESH:-/usr/local/bin/acme.sh}
DEPLOY_HOOK=${DEPLOY_HOOK}

# Check base required environment variables
[ -z "$DOMAINS" ] && echo "Error: DOMAINS not set" && exit 1
[ -z "$CF_Token" ] && echo "Error: CF_Token not set" && exit 1
[ -z "$CF_Email" ] && echo "Error: CF_Email not set" && exit 1
[ -z "$ACME_EMAIL" ] && echo "Error: ACME_EMAIL not set" && exit 1
[ -z "$DEPLOY_HOOK" ] && echo "Error: DEPLOY_HOOK not set (use 'synology_dsm' or 'ssh')" && exit 1

# Get the main domain (first in the list)
MAIN_DOMAIN=$(echo "$DOMAINS" | awk '{print $1}')

# Build the domain parameters for acme.sh
DOMAIN_PARAMS="-d ${MAIN_DOMAIN}"
for domain in $(echo "$DOMAINS" | cut -d' ' -f2-); do
    DOMAIN_PARAMS="$DOMAIN_PARAMS -d $domain"
done

# Check hook-specific required variables
case "${DEPLOY_HOOK}" in
    "synology_dsm")
        [ -z "$SYNO_HOSTNAME" ] && echo "Error: SYNO_HOSTNAME not set" && exit 1
        [ -z "$SYNO_USERNAME" ] && echo "Error: SYNO_USERNAME not set" && exit 1
        [ -z "$SYNO_PASSWORD" ] && echo "Error: SYNO_PASSWORD not set" && exit 1
        export SYNO_USERNAME="${SYNO_USERNAME}"
        export SYNO_PASSWORD="${SYNO_PASSWORD}"
        export SYNO_CERTIFICATE="${MAIN_DOMAIN}"
        export SYNO_SCHEME=${SYNO_SCHEME:-https}
        export SYNO_PORT=${SYNO_PORT}
        export SYNO_CREATE=${SYNO_CREATE:-1}
        [ "${SYNO_SCHEME}" = "https" ] && export SYNO_Insecure="${SYNO_INSECURE:-1}"
        ;;
    "ssh")
        [ -z "$SSH_HOST" ] && echo "Error: SSH_HOST not set" && exit 1
        [ -z "$SSH_USER" ] && echo "Error: SSH_USER not set" && exit 1
        export SSH_DEPLOY_USER="${SSH_USER}"
        export SSH_DEPLOY_HOST="${SSH_HOST}"
        # Optional SSH parameters with their defaults
        export SSH_DEPLOY_PORT="${SSH_PORT:-22}"
        export SSH_DEPLOY_KEY="${SSH_KEY:-}"
        export SSH_DEPLOY_REMOTE_CMD="${SSH_CMD:-}"
        export SSH_DEPLOY_KEY_PASS="${SSH_KEY_PASS:-}"
        # Target paths for certificate files
        export SSH_DEPLOY_CERT_PATH="${SSH_CERT_PATH:-/etc/ssl/${MAIN_DOMAIN}.crt}"
        export SSH_DEPLOY_KEY_PATH="${SSH_KEY_PATH:-/etc/ssl/${MAIN_DOMAIN}.key}"
        export SSH_DEPLOY_CA_PATH="${SSH_CA_PATH:-/etc/ssl/${MAIN_DOMAIN}.ca}"
        export SSH_DEPLOY_FULLCHAIN_PATH="${SSH_FULLCHAIN_PATH:-/etc/ssl/${MAIN_DOMAIN}.fullchain.cer}"
        # Optional reload command
        export SSH_DEPLOY_RELOAD_CMD="${SSH_RELOAD_CMD:-}"
        ;;
    *)
        echo "Error: DEPLOY_HOOK must be either 'synology_dsm' or 'ssh'"
        exit 1
        ;;
esac

# Check if certificate exists
if ${ACMESH} --list | grep -q "${MAIN_DOMAIN}"; then
    # Get renewal date (last field, in format 2025-01-03T05:20:17Z)
    cert_line=$(${ACMESH} --list | grep "${MAIN_DOMAIN}")
    renewal_date=$(echo "$cert_line" | awk '{print $(NF)}')
    now=$(date '+%Y-%m-%dT%H:%M:%SZ')

    # Convert dates to epoch
    renew_time=$(date -d "${renewal_date}" +%s)
    current_time=$(date -d "${now}" +%s)
    days_remaining=$(( (renew_time - current_time) / 86400 ))

    if [ "${days_remaining}" -gt 30 ] 2>/dev/null; then
        echo "Certificate for ${MAIN_DOMAIN} exists with ${days_remaining} days remaining."
        ${ACMESH} --deploy -d ${MAIN_DOMAIN} --deploy-hook "${DEPLOY_HOOK}" --insecure
        exit $?
    else
        echo "Certificate exists but only ${days_remaining} days remaining. Renewing..."
        ${ACMESH} --renew ${DOMAIN_PARAMS} --force --server letsencrypt --dns dns_cf
        if [ $? -eq 0 ]; then
            echo "Certificate renewed successfully. Deploying..."
            ${ACMESH} --deploy -d ${MAIN_DOMAIN} --deploy-hook "${DEPLOY_HOOK}" --insecure
            exit $?
        else
            echo "Failed to renew certificate"
            exit 1
        fi
    fi
fi

# Issue new certificate if it doesn't exist
echo "Issuing new certificate for ${MAIN_DOMAIN}..."
${ACMESH} --issue ${DOMAIN_PARAMS} --dns dns_cf --keylength 4096 --server letsencrypt

if [ $? -eq 0 ]; then
    echo "Certificate issued successfully. Deploying..."
    ${ACMESH} --deploy -d ${MAIN_DOMAIN} --deploy-hook "${DEPLOY_HOOK}"
    exit $?
else
    echo "Failed to issue certificate"
    exit 1
fi
