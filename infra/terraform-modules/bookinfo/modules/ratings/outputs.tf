output "service" {
  description = "Configured ratings Service reference; readiness needs runtime verification."
  value = {
    name        = "ratings"
    port        = 9080
    target_port = 9080
    dns_name    = "ratings.${helm_release.this.namespace}.svc.cluster.local"
  }
}
