set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

kubernetes_dir := justfile_dir() + '/kubernetes'
terraform_dir := justfile_dir() + '/terraform/authentik'

[private]
default:
    just -l authentik

[doc('terraform init')]
init:
  cd "{{ terraform_dir }}" && terraform init

[doc('terraform plan')]
plan:
  just authentik init
  cd "{{ terraform }}" && terraform plan

[doc('terraform apply')]
apply:
  just authentik init
  cd "{{ terraform_dir }}" && terraform apply -auto-approve
