output "service" {
  description = "Configured details Service reference; readiness needs runtime verification."
  value = {
    name        = "details"
    port        = 9080
    target_port = 9080
    dns_name    = "details.${helm_release.this.namespace}.svc.cluster.local"
  }
}
