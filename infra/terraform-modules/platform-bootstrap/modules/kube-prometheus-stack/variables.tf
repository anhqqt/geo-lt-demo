# Helm release

variable "release_name" {
  description = "Name of the Helm release."
  type        = string
  default     = "monitoring"
  nullable    = false
}

variable "namespace" {
  description = "Namespace for the kube-prometheus-stack release."
  type        = string
  default     = "monitoring"
  nullable    = false
}

variable "repository" {
  description = "Helm repository containing the monitoring chart."
  type        = string
  default     = "https://prometheus-community.github.io/helm-charts"
  nullable    = false
}

variable "chart_name" {
  description = "Name of the monitoring Helm chart."
  type        = string
  default     = "kube-prometheus-stack"
  nullable    = false
}

variable "chart_version" {
  description = "Exact version of the kube-prometheus-stack Helm chart."
  type        = string
  default     = "91.8.2"
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.chart_version))
    error_message = "Use an exact stable chart version."
  }
}

# Grafana Ingress

variable "grafana_ingress_enable" {
  description = "Expose Grafana through an ALB Ingress with HTTPS."
  type        = bool
  default     = false
  nullable    = false
}

variable "grafana_ingress_host" {
  description = "Grafana hostname without a scheme or path; required when Ingress is enabled."
  type        = string
  default     = ""
  nullable    = false

  validation {
    condition = !var.grafana_ingress_enable || (
      length(var.grafana_ingress_host) <= 253 &&
      can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", var.grafana_ingress_host))
    )
    error_message = "Set grafana_ingress_host to a DNS hostname without a scheme or path when Ingress is enabled."
  }
}

variable "grafana_ingress_annotations" {
  description = "Grafana Ingress annotations; supplied keys override the shared ALB defaults."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition     = alltrue([for value in values(var.grafana_ingress_annotations) : value != null])
    error_message = "Ingress annotation values must be strings, not null."
  }
}

# Helm overrides

variable "context" {
  description = "Additional Helm values in set notation."
  type        = map(string)
  default     = {}
  nullable    = false

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
    timeout                    = optional(number, 900)
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
