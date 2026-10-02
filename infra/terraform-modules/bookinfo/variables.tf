variable "aws_region" {
  description = "Region of the existing EKS cluster, used by token exec authentication."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+$", var.aws_region))
    error_message = "Use the AWS region containing the existing cluster."
  }
}

variable "cluster_name" {
  description = "Existing cluster name from the cluster unit output."
  type        = string
  nullable    = false
  validation {
    condition     = length(trimspace(var.cluster_name)) > 0
    error_message = "The existing cluster name must be nonempty."
  }
}

variable "cluster_endpoint" {
  description = "Existing HTTPS Kubernetes API endpoint, without a path."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^https://[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$", var.cluster_endpoint))
    error_message = "Use the existing HTTPS cluster endpoint without a path, query or credentials."
  }
}

variable "cluster_certificate_authority_data" {
  description = "Base64 cluster CA from the cluster unit output."
  type        = string
  nullable    = false
  validation {
    condition     = can(base64decode(var.cluster_certificate_authority_data)) && length(var.cluster_certificate_authority_data) > 0
    error_message = "The cluster CA must be nonempty base64 data."
  }
}

variable "tags" {
  description = "Shared AWS tags used for the IngressGroup's ALB resources."
  type        = map(string)
  default     = {}
  nullable    = false
  validation {
    condition     = alltrue([for value in values(var.tags) : value != null])
    error_message = "Tag values must be strings, not null."
  }
}

variable "namespace" {
  description = "Namespace owned exclusively by this Bookinfo pillar."
  type        = string
  default     = "bookinfo"
  nullable    = false
  validation {
    condition = (
      length(var.namespace) <= 63 &&
      can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.namespace)) &&
      !startswith(var.namespace, "kube-") &&
      !contains(["default", "monitoring", "k6-operator", "k6-runners"], var.namespace)
    )
    error_message = "Use a DNS label of at most 63 characters outside default, kube-*, monitoring, k6-operator and k6-runners namespaces."
  }
}

variable "enable_ratings" {
  description = "Manage the ratings Helm release in the shared Bookinfo namespace."
  type        = bool
  default     = true
  nullable    = false
}

variable "ratings" {
  description = "Ratings release settings; omitted fields use the child module and chart defaults."
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
  validation {
    condition     = var.ratings.namespace == null || var.ratings.namespace == var.namespace
    error_message = "Ratings must use the shared Bookinfo namespace; set namespace at the pillar root."
  }
}

variable "enable_details" {
  description = "Manage the details Helm release in the shared Bookinfo namespace."
  type        = bool
  default     = true
  nullable    = false
}

variable "details" {
  description = "Details release settings; omitted fields use the child module and chart defaults."
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
  validation {
    condition     = var.details.namespace == null || var.details.namespace == var.namespace
    error_message = "Details must use the shared Bookinfo namespace; set namespace at the pillar root."
  }
}

variable "enable_review" {
  description = "Manage the review Helm release in the shared Bookinfo namespace."
  type        = bool
  default     = true
  nullable    = false
}

variable "review" {
  description = "Review release settings; omitted fields use the child module and chart defaults."
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
  validation {
    condition     = var.review.namespace == null || var.review.namespace == var.namespace
    error_message = "Review must use the shared Bookinfo namespace; set namespace at the pillar root."
  }
}

variable "enable_productpage" {
  description = "Manage the productpage Helm release in the shared Bookinfo namespace."
  type        = bool
  default     = true
  nullable    = false
}

variable "productpage" {
  description = "Productpage release settings; omitted fields use the child module and chart defaults."
  type = object({
    release_name        = optional(string)
    namespace           = optional(string)
    repository          = optional(string)
    chart_name          = optional(string)
    chart_version       = optional(string)
    context             = optional(map(string), {})
    context_sensitive   = optional(map(string), {})
    helm_options        = optional(any, {})
    ingress_enable      = optional(bool)
    ingress_host        = optional(string)
    ingress_annotations = optional(map(string), {})
  })
  default  = {}
  nullable = false
  validation {
    condition     = var.productpage.namespace == null || var.productpage.namespace == var.namespace
    error_message = "Productpage must use the shared Bookinfo namespace; set namespace at the pillar root."
  }
}
