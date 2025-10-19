#!/usr/bin/env -S just --justfile

set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

mod bootstrap "bootstrap"
mod kube "kubernetes"
mod rook "kubernetes/apps/rook-ceph"
mod talos "talos"

[private]
default:
  just -l

[private]
log lvl msg *args:
  gum log -t rfc3339 -s -l "{{ lvl }}" "{{ msg }}" {{ args }}

[private]
spin title *cmd:
  gum spin --title="{{ title }}" -- {{ cmd }}

[private]
template file *args:
  minijinja-cli "{{ file }}" {{ args }} | op inject
