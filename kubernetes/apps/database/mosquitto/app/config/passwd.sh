#!/bin/sh
# Builds the Mosquitto password file from every <NAME>_USER / <NAME>_PASS pair in
# /secret (mosquitto-secret mounted as files), replacing it atomically.
set -eu
out=/mosquitto-init/mosquitto.passwd
tmp=$(mktemp /mosquitto-init/passwd.XXXXXX)
n=0
for user in /secret/*_USER; do
  pass="${user%_USER}_PASS"
  if [ ! -s "$user" ] || [ ! -s "$pass" ]; then
    echo "skipping $(basename "$user" _USER): user or password is empty" >&2
    continue
  fi
  mosquitto_passwd -b "$tmp" "$(cat "$user")" "$(cat "$pass")"
  n=$((n + 1))
done
chmod 0600 "$tmp"
mv "$tmp" "$out"
echo "password file has $n users"
