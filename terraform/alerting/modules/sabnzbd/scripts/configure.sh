#!/bin/bash
set -euo pipefail

# Read configuration from environment variables
API_KEY="$SABNZBD_API_KEY"
URL="$SABNZBD_URL"
CONFIG_JSON="$SABNZBD_CONFIG"

# Function to make API call with timeout
make_api_call() {
  local section="$1"
  local keyword="$2"
  local value="$3"
  
  curl -s -X POST "${URL}/api" \
    -d "apikey=${API_KEY}" \
    -d "mode=set_config" \
    -d "section=${section}" \
    -d "keyword=${keyword}" \
    -d "value=${value}" \
    --connect-timeout 5 \
    --max-time 10 \
    -w "\n" || {
      echo "Warning: Failed to set ${section}.${keyword}"
      return 0
    }
}

echo "Starting SABnzbd configuration..."
echo "URL: ${URL}"

# Test connection first
echo "Testing connection..."
if ! curl -s -f --connect-timeout 5 --max-time 10 "${URL}/api?mode=version&apikey=${API_KEY}" >/dev/null; then
  echo "ERROR: Cannot connect to SABnzbd at ${URL}"
  exit 1
fi

echo "Connection successful, applying configuration..."

# Configure general settings
echo "$CONFIG_JSON" | jq -r '.general_settings | to_entries[] | "\(.key)|\(.value)"' | while IFS='|' read -r key value; do
  echo -n "Setting general.${key}... "
  make_api_call "misc" "$key" "$value"
done

# Configure directories
echo -n "Setting download_dir... "
make_api_call "misc" "download_dir" "$(echo "$CONFIG_JSON" | jq -r '.download_dir')"
echo -n "Setting complete_dir... "
make_api_call "misc" "complete_dir" "$(echo "$CONFIG_JSON" | jq -r '.complete_dir')"

# Configure categories
echo "$CONFIG_JSON" | jq -r '.categories | keys[]' | while read -r name; do
  echo -n "Setting category ${name}... "
  cat_json=$(echo "$CONFIG_JSON" | jq -c ".categories[\"$name\"]")
  make_api_call "categories" "$name" "$cat_json"
done

# Configure servers
echo "$CONFIG_JSON" | jq -r '.servers | to_entries[] | "\(.value.host)|\(.key)"' | while IFS='|' read -r host name; do
  echo -n "Setting server ${name}... "
  server_json=$(echo "$CONFIG_JSON" | jq -c ".servers[\"$name\"]")
  make_api_call "servers" "$host" "$server_json"
done

# Configure switches
echo "$CONFIG_JSON" | jq -r '.switches | to_entries[] | "\(.key)|\(.value)"' | while IFS='|' read -r key value; do
  echo -n "Setting switch.${key}... "
  make_api_call "misc" "$key" "$value"
done

# Save configuration
echo -n "Saving configuration... "
curl -s -X POST "${URL}/api" \
  -d "apikey=${API_KEY}" \
  -d "mode=config" \
  -d "name=save" \
  --connect-timeout 5 \
  --max-time 10 || echo "Warning: Failed to save"

echo -e "\nSABnzbd configuration completed"