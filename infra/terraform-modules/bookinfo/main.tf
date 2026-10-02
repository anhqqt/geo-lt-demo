resource "kubernetes_namespace_v1" "bookinfo" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/part-of" = "bookinfo"
    }
  }
}

module "ratings" {
  count             = var.enable_ratings ? 1 : 0
  source            = "./modules/ratings"
  release_name      = var.ratings.release_name
  namespace         = coalesce(var.ratings.namespace, kubernetes_namespace_v1.bookinfo.metadata[0].name)
  repository        = var.ratings.repository
  chart_name        = var.ratings.chart_name
  chart_version     = var.ratings.chart_version
  context           = var.ratings.context
  context_sensitive = var.ratings.context_sensitive
  helm_options      = var.ratings.helm_options

  depends_on = [kubernetes_namespace_v1.bookinfo]
}

module "details" {
  count             = var.enable_details ? 1 : 0
  source            = "./modules/details"
  release_name      = var.details.release_name
  namespace         = coalesce(var.details.namespace, kubernetes_namespace_v1.bookinfo.metadata[0].name)
  repository        = var.details.repository
  chart_name        = var.details.chart_name
  chart_version     = var.details.chart_version
  context           = var.details.context
  context_sensitive = var.details.context_sensitive
  helm_options      = var.details.helm_options

  depends_on = [kubernetes_namespace_v1.bookinfo]
}

module "review" {
  count             = var.enable_review ? 1 : 0
  source            = "./modules/review"
  release_name      = var.review.release_name
  namespace         = coalesce(var.review.namespace, kubernetes_namespace_v1.bookinfo.metadata[0].name)
  repository        = var.review.repository
  chart_name        = var.review.chart_name
  chart_version     = var.review.chart_version
  context           = var.review.context
  context_sensitive = var.review.context_sensitive
  helm_options      = var.review.helm_options

  depends_on = [kubernetes_namespace_v1.bookinfo]
}

module "productpage" {
  count             = var.enable_productpage ? 1 : 0
  source            = "./modules/productpage"
  release_name      = var.productpage.release_name
  namespace         = coalesce(var.productpage.namespace, kubernetes_namespace_v1.bookinfo.metadata[0].name)
  repository        = var.productpage.repository
  chart_name        = var.productpage.chart_name
  chart_version     = var.productpage.chart_version
  context           = var.productpage.context
  context_sensitive = var.productpage.context_sensitive
  helm_options      = var.productpage.helm_options
  ingress_enable    = var.productpage.ingress_enable
  ingress_host      = var.productpage.ingress_host
  ingress_annotations = merge(
    length(var.tags) == 0 ? {} : {
      "alb.ingress.kubernetes.io/tags" = join(",", [for key, value in var.tags : "${key}=${value}"])
    },
    var.productpage.ingress_annotations,
  )

  depends_on = [kubernetes_namespace_v1.bookinfo]
}
