# 1Password secrets
module "secrets" {
  source = "./modules/onepassword"
  vault  = var.onepassword_vault
  items  = [var.onepassword_item]
}

# Use existing observability namespace
data "kubernetes_namespace" "observability" {
  metadata {
    name = "observability"
  }
}

# ConfigMap for test scripts
resource "kubernetes_config_map" "k6_tests" {
  for_each = coalesce(var.k6_tests, local.k6_test_configs)

  metadata {
    name      = "${each.key}-test"
    namespace = data.kubernetes_namespace.observability.metadata[0].name
  }

  data = {
    "test.js" = each.value.script
  }
}

# ServiceAccount for CronJobs to create TestRun CRDs
resource "kubernetes_service_account" "k6_test_runner" {
  metadata {
    name      = "k6-test-runner"
    namespace = data.kubernetes_namespace.observability.metadata[0].name
  }
}

# Role for creating TestRun CRDs
resource "kubernetes_role" "k6_test_runner" {
  metadata {
    name      = "k6-test-runner"
    namespace = data.kubernetes_namespace.observability.metadata[0].name
  }

  rule {
    api_groups = ["k6.io"]
    resources  = ["testruns"]
    verbs      = ["create", "delete", "get", "list", "patch", "update", "watch"]
  }
}

# RoleBinding
resource "kubernetes_role_binding" "k6_test_runner" {
  metadata {
    name      = "k6-test-runner"
    namespace = data.kubernetes_namespace.observability.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.k6_test_runner.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.k6_test_runner.metadata[0].name
    namespace = data.kubernetes_namespace.observability.metadata[0].name
  }
}

# CronJobs for scheduled tests that create TestRun CRDs

resource "kubernetes_cron_job_v1" "k6_tests" {
  for_each = { for k, v in coalesce(var.k6_tests, local.k6_test_configs) : k => v if v.schedule != "" }

  metadata {
    name      = "${each.key}-scheduler"
    namespace = data.kubernetes_namespace.observability.metadata[0].name
  }

  spec {
    schedule                      = each.value.schedule
    concurrency_policy           = "Replace"
    successful_jobs_history_limit = 1
    failed_jobs_history_limit    = 1

    job_template {
      metadata {
        labels = {
          app  = "k6-scheduler"
          test = each.key
        }
      }

      spec {
        template {
          metadata {
            labels = {
              app  = "k6-scheduler"
              test = each.key
            }
          }

          spec {
            service_account_name = kubernetes_service_account.k6_test_runner.metadata[0].name
            restart_policy      = "OnFailure"

            container {
              name  = "testrun-creator"
              image = "bitnami/kubectl:latest"

              command = ["/bin/sh", "-c"]
              args = [<<-EOT
                TIMESTAMP=$(date +%s)
                cat <<YAML | kubectl apply -f -
                apiVersion: k6.io/v1alpha1
                kind: TestRun
                metadata:
                  name: ${each.key}-$${TIMESTAMP}
                  namespace: ${data.kubernetes_namespace.observability.metadata[0].name}
                spec:
                  parallelism: 1
                  script:
                    configMap:
                      name: ${kubernetes_config_map.k6_tests[each.key].metadata[0].name}
                      file: test.js
                  arguments: "--out experimental-prometheus-rw"
                  runner:
                    metadata:
                      labels:
                        test_name: "${each.key}"
                        test_type: "synthetic"
                        app: "k6-test"
                      annotations:
                        promtail.io/log-format: "json"
                    env:%{ for k, v in each.value.env_vars }
                    - name: "${k}"
                      value: "${v}"%{ endfor }%{ for k, v in each.value.secret_env_vars }
                    - name: "${k}"
                      valueFrom:
                        secretKeyRef:
                          name: "${v.secret_name}"
                          key: "${v.secret_key}"%{ endfor }
                    - name: "K6_PROMETHEUS_RW_SERVER_URL"
                      value: "http://kube-prometheus-stack-prometheus.observability.svc.cluster.local:9090/api/v1/write"
                    - name: "K6_PROMETHEUS_RW_TREND_AS_NATIVE_HISTOGRAM"
                      value: "true"
                    - name: "K6_PROMETHEUS_RW_TREND_STATS"
                      value: "p(95),p(99),min,max,avg,med"
                    resources:
                      requests:
                        memory: "${each.value.resources.memory_request}"
                        cpu: "${each.value.resources.cpu_request}"
                      limits:
                        memory: "${each.value.resources.memory_limit}"
                        cpu: "${each.value.resources.cpu_limit}"
                YAML
              EOT
              ]

              resources {
                requests = {
                  cpu    = "10m"
                  memory = "32Mi"
                }
                limits = {
                  cpu    = "50m"
                  memory = "64Mi"
                }
              }
            }
          }
        }
      }
    }
  }
}