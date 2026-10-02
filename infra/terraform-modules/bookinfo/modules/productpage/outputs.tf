output "service" {
  description = "Configured productpage Service reference; readiness needs runtime verification."
  value = {
    name        = "productpage"
    port        = 80
    target_port = 9080
    dns_name    = "productpage.${helm_release.this.namespace}.svc.cluster.local"
  }
}

output "ingress_name" {
  description = "Configured Ingress name; null when public exposure is disabled."
  value       = var.ingress_enable ? "bookinfo" : null
}

output "public_url" {
  description = "Configured public productpage URL; DNS, TLS and target readiness need runtime checks."
  value       = var.ingress_enable ? "https://${var.ingress_host}/productpage" : null
}
