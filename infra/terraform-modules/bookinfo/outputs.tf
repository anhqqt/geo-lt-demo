output "namespace" {
  description = "Namespace owned by the Bookinfo pillar."
  value       = kubernetes_namespace_v1.bookinfo.metadata[0].name
}

output "services" {
  description = "Internal service addresses and ports; these references do not establish runtime readiness."
  value = merge(
    var.enable_ratings ? { ratings = module.ratings[0].service } : {},
    var.enable_details ? { details = module.details[0].service } : {},
    var.enable_review ? { review = module.review[0].service } : {},
    var.enable_productpage ? { productpage = module.productpage[0].service } : {},
  )
}

output "internal_url" {
  description = "Internal productpage URL; null when productpage is disabled. Readiness needs runtime verification."
  value       = var.enable_productpage ? "http://${module.productpage[0].service.dns_name}/productpage" : null
}

output "ingress_name" {
  description = "Productpage Ingress name; null when the service or its Ingress is disabled."
  value       = var.enable_productpage ? module.productpage[0].ingress_name : null
}

output "public_url" {
  description = "Configured public productpage URL; not a runtime readiness signal."
  value       = var.enable_productpage ? module.productpage[0].public_url : null
}
