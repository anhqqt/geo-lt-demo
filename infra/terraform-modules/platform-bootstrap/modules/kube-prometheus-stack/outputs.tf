output "release_name" {
  value = helm_release.this.name
}

output "namespace" {
  value = helm_release.this.namespace
}

output "prometheus_url" {
  value = "http://${var.release_name}-prometheus.${var.namespace}.svc.cluster.local:9090"
}

output "remote_write_url" {
  value = "http://${var.release_name}-prometheus.${var.namespace}.svc.cluster.local:9090/api/v1/write"
}

output "grafana_service" {
  value = "${var.release_name}-grafana"
}

output "grafana_admin_secret" {
  value = "${var.release_name}-grafana"
}

output "grafana_url" {
  value = var.grafana_ingress_enable ? "https://${var.grafana_ingress_host}" : null
}
