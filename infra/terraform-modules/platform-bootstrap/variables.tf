variable "aws_region" {
  type        = string
  description = "Region of the existing cluster."
  nullable    = false
}

variable "cluster_name" {
  type        = string
  description = "Existing cluster output; bootstrap never creates a cluster."
  nullable    = false
}

variable "cluster_endpoint" {
  type        = string
  description = "Existing HTTPS API endpoint."
  nullable    = false
  validation {
    condition     = can(regex("^https://[^/]+$", var.cluster_endpoint))
    error_message = "Use the existing HTTPS cluster endpoint."
  }
}

variable "cluster_certificate_authority_data" {
  type        = string
  description = "Base64 cluster CA from the existing state."
  nullable    = false
  validation {
    condition     = can(base64decode(var.cluster_certificate_authority_data))
    error_message = "The cluster CA must be base64 encoded."
  }
}

variable "tags" {
  type     = map(string)
  default  = {}
  nullable = false
}

# Load Balancer Controller
variable "enable_alb_controller" {
  type        = bool
  description = "Manage the controller and its Pod Identity resources."
  default     = true
  nullable    = false
}

variable "vpc_id" {
  type        = string
  description = "Existing VPC ID."
  nullable    = false
}
variable "alb_controller" {
  description = "ALB Controller release settings; omitted fields use the child module defaults."
  type = object({
    release_name      = optional(string)
    namespace         = optional(string)
    repository        = optional(string)
    chart_name        = optional(string)
    chart_version     = optional(string)
    context           = optional(map(string), {})
    context_sensitive = optional(map(string), {})
    helm_options      = optional(any, {})
  })
  default  = {}
  nullable = false
}


# Cluster Autoscaler

variable "enable_cluster_autoscaler" {
  description = "Manage Cluster Autoscaler and its Pod Identity resources."
  type        = bool
  default     = true
  nullable    = false
}

variable "cluster_autoscaler" {
  description = "Cluster Autoscaler release settings; omitted fields use the child module defaults."
  type = object({
    release_name      = optional(string)
    namespace         = optional(string)
    repository        = optional(string)
    chart_name        = optional(string)
    chart_version     = optional(string)
    context           = optional(map(string), {})
    context_sensitive = optional(map(string), {})
    helm_options      = optional(any, {})
  })
  default  = {}
  nullable = false
}

# ExternalDNS

variable "enable_external_dns" {
  description = "Manage ExternalDNS and its Pod Identity resources."
  type        = bool
  default     = true
  nullable    = false
}

variable "external_dns" {
  description = "ExternalDNS settings; DNS zone fields are required when enabled, and release fields use child defaults."
  type = object({
    dns_zone_id       = optional(string)
    dns_zone_name     = optional(string)
    release_name      = optional(string)
    namespace         = optional(string)
    repository        = optional(string)
    chart_name        = optional(string)
    chart_version     = optional(string)
    context           = optional(map(string), {})
    context_sensitive = optional(map(string), {})
    helm_options      = optional(any, {})
  })
  default  = {}
  nullable = false
}

# Metrics Server

variable "enable_metrics_server" {
  description = "Manage Metrics Server and its chart-owned Kubernetes resources."
  type        = bool
  default     = true
  nullable    = false
}

variable "metrics_server" {
  description = "Metrics Server release settings; omitted fields use the child module defaults."
  type = object({
    release_name      = optional(string)
    namespace         = optional(string)
    repository        = optional(string)
    chart_name        = optional(string)
    chart_version     = optional(string)
    context           = optional(map(string), {})
    context_sensitive = optional(map(string), {})
    helm_options      = optional(any, {})
  })
  default  = {}
  nullable = false
}

# k6 Operator

variable "enable_k6_operator" {
  description = "Manage k6 Operator and its workflow access."
  type        = bool
  default     = true
  nullable    = false
}

variable "cluster_arn" {
  description = "Existing EKS cluster ARN for the workflow's DescribeCluster permission."
  type        = string
  nullable    = false
}

variable "k6_operator" {
  description = "k6 Operator settings; GitHub identity fields are required when enabled, and release fields use child defaults."
  type = object({
    github_oidc_provider_arn = optional(string)
    github_oidc_subject      = optional(string)
    release_name             = optional(string)
    namespace                = optional(string)
    runner_namespace         = optional(string)
    repository               = optional(string)
    chart_name               = optional(string)
    chart_version            = optional(string)
    context                  = optional(map(string), {})
    context_sensitive        = optional(map(string), {})
    helm_options             = optional(any, {})
  })
  default  = {}
  nullable = false
}

# kube-prometheus-stack

variable "enable_kube_prometheus_stack" {
  description = "Manage Prometheus, Grafana and Prometheus Operator."
  type        = bool
  default     = true
  nullable    = false
}

variable "kube_prometheus_stack" {
  description = "Monitoring release settings; omitted fields use the child module defaults."
  type = object({
    release_name                = optional(string)
    namespace                   = optional(string)
    repository                  = optional(string)
    chart_name                  = optional(string)
    chart_version               = optional(string)
    grafana_ingress_enable      = optional(bool)
    grafana_ingress_host        = optional(string)
    grafana_ingress_annotations = optional(map(string), {})
    context                     = optional(map(string), {})
    context_sensitive           = optional(map(string), {})
    helm_options                = optional(any, {})
  })
  default  = {}
  nullable = false
}
