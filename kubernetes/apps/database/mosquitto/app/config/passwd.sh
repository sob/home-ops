#!/bin/sh
# Builds the Mosquitto password file from every <NAME>_USER / <NAME>_PASS pair in
# /secret (mosquitto-secret mounted as files), and the ACL file from the same
# users, replacing both atomically. Usernames come from 1Password, so the ACL
# is generated here rather than kept in git.
set -eu

# Topics each user may use, keyed by the secret name. By default a bridge owns
# <name>/# (hue -> hue/#). Clients that publish Home Assistant discovery also
# get homeassistant/#.
rules() {
  case "$1" in
    EXPORTER) echo "topic read #" ;;           # mqtt-exporter, audit log
    NODERED) echo "topic readwrite #" ;;       # automations drive every bridge
    ZIGBEE) printf 'topic readwrite zigbee2mqtt/#\ntopic readwrite homeassistant/#\n' ;;
    RTLAMR) printf 'topic readwrite rtlamr/#\ntopic readwrite homeassistant/#\n' ;;
    RING) printf 'topic readwrite ring/#\ntopic readwrite homeassistant/#\n' ;;
    HASS | N8N) ;;                             # retired: can log in, no topics
    *) echo "topic readwrite $(echo "$1" | tr '[:upper:]' '[:lower:]')/#" ;;
  esac
}

out=/mosquitto-init/mosquitto.passwd
acl=/mosquitto-init/mosquitto.acl
tmp=$(mktemp /mosquitto-init/passwd.XXXXXX)
tmpacl=$(mktemp /mosquitto-init/acl.XXXXXX)
n=0
for user in /secret/*_USER; do
  name=$(basename "$user" _USER)
  pass="${user%_USER}_PASS"
  if [ ! -s "$user" ] || [ ! -s "$pass" ]; then
    echo "skipping $name: user or password is empty" >&2
    continue
  fi
  mosquitto_passwd -b "$tmp" "$(cat "$user")" "$(cat "$pass")"
  printf 'user %s\n%s\n\n' "$(cat "$user")" "$(rules "$name")" >> "$tmpacl"
  n=$((n + 1))
done
chmod 0600 "$tmp" "$tmpacl"
mv "$tmp" "$out"
mv "$tmpacl" "$acl"
echo "password and ACL files have $n users"
