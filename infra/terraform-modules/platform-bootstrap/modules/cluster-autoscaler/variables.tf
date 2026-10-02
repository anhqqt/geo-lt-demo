# Cluster and AWS resources

variable "aws_region" {
  description = "AWS region containing the EKS cluster."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name used by the controller and Pod Identity association."
  type        = string
}

variable "tags" {
  description = "Tags applied to the controller IAM and Pod Identity resources."
  type        = map(string)
}

# Helm release

variable "release_name" {
  description = "Name of the Helm release."
  type        = string
  default     = "cluster-autoscaler"
  nullable    = false
}

variable "namespace" {
  description = "Namespace for the controller release and Pod Identity association."
  type        = string
  default     = "kube-system"
  nullable    = false
}

variable "repository" {
  description = "Helm repository containing the controller chart."
  type        = string
  default     = "https://kubernetes.github.io/autoscaler"
  nullable    = false
}

variable "chart_name" {
  description = "Name of the controller Helm chart."
  type        = string
  default     = "cluster-autoscaler"
  nullable    = false
}

variable "chart_version" {
  description = "Exact version of the Cluster Autoscaler Helm chart."
  type        = string
  default     = "9.59.0"
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.chart_version))
    error_message = "Use an exact stable chart version."
  }
}

variable "context" {
  description = "Additional Helm values in set notation; cluster and ServiceAccount wiring are module-owned."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition = alltrue([
      for key in concat(keys(var.context), keys(var.context_sensitive)) :
      !contains([
        "cloudProvider",
        "awsRegion",
        "autoDiscovery",
        "autoDiscovery.clusterName",
        "autoDiscovery.tags",
        "autoscalingGroups",
        "rbac",
        "rbac.create",
        "rbac.serviceAccount",
        "rbac.serviceAccount.name",
        "rbac.serviceAccount.create",
      ], key)
    ])
    error_message = "Use module inputs for cluster settings; keep the module-owned ServiceAccount for Pod Identity."
  }

  validation {
    condition     = alltrue([for value in values(var.context) : value != null])
    error_message = "Helm set values must be strings, not null."
  }
}

variable "context_sensitive" {
  description = "Sensitive Helm values passed through set_sensitive."
  type        = map(string)
  default     = {}
  nullable    = false
  sensitive   = true

  validation {
    condition     = alltrue([for value in values(var.context_sensitive) : value != null])
    error_message = "Sensitive Helm set values must be strings, not null."
  }
}

variable "helm_options" {
  description = "Helm operation options; omitted or null fields use these defaults."
  type = object({
    force_update               = optional(bool, false)
    wait                       = optional(bool, true)
    timeout                    = optional(number, 300)
    recreate_pods              = optional(bool, false)
    max_history                = optional(number, 0)
    lint                       = optional(bool, false)
    cleanup_on_fail            = optional(bool, false)
    create_namespace           = optional(bool, true)
    disable_webhooks           = optional(bool, false)
    verify                     = optional(bool, false)
    reuse_values               = optional(bool, false)
    reset_values               = optional(bool, false)
    atomic                     = optional(bool, false)
    skip_crds                  = optional(bool, false)
    disable_crd_hooks          = optional(bool, false)
    render_subchart_notes      = optional(bool, true)
    disable_openapi_validation = optional(bool, false)
    wait_for_jobs              = optional(bool, false)
    dependency_update          = optional(bool, false)
    replace                    = optional(bool, false)
    pass_credentials           = optional(bool, false)
    take_ownership             = optional(bool, false)
    upgrade_install            = optional(bool, true)
  })
  default  = {}
  nullable = false
}
