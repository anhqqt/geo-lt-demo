output "service" {
  description = "Configured review Service reference; readiness needs runtime verification."
  value = {
    name        = "review"
    port        = 9080
    target_port = 9080
    dns_name    = "review.${helm_release.this.namespace}.svc.cluster.local"
  }
}
