# Helm release

variable "release_name" {
  description = "Name of the Helm release."
  type        = string
  default     = "ratings"
  nullable    = false
}

variable "namespace" {
  description = "Namespace for the ratings release."
  type        = string
  default     = "bookinfo"
  nullable    = false
}

variable "repository" {
  description = "Optional repository for a compatible replacement chart; empty uses the bundled local chart."
  type        = string
  default     = ""
  nullable    = false
}

variable "chart_name" {
  description = "Compatible chart name or path; empty selects the bundled charts/ratings directory."
  type        = string
  default     = ""
  nullable    = false
}

variable "chart_version" {
  description = "Exact version of the ratings Helm chart."
  type        = string
  default     = "0.1.2"
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.chart_version))
    error_message = "Use an exact stable chart version."
  }
}

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
    timeout                    = optional(number, 600)
    recreate_pods              = optional(bool, false)
    max_history                = optional(number, 2)
    lint                       = optional(bool, false)
    cleanup_on_fail            = optional(bool, false)
    create_namespace           = optional(bool, false)
    disable_webhooks           = optional(bool, false)
    verify                     = optional(bool, false)
    reuse_values               = optional(bool, false)
    reset_values               = optional(bool, true)
    atomic                     = optional(bool, false)
    skip_crds                  = optional(bool, false)
    disable_crd_hooks          = optional(bool, false)
    render_subchart_notes      = optional(bool, true)
    disable_openapi_validation = optional(bool, false)
    wait_for_jobs              = optional(bool, false)
    dependency_update          = optional(bool, true)
    replace                    = optional(bool, false)
    pass_credentials           = optional(bool, false)
    take_ownership             = optional(bool, false)
    upgrade_install            = optional(bool, true)
  })
  default  = {}
  nullable = false
  validation {
    condition = (
      var.helm_options.timeout > 0 && floor(var.helm_options.timeout) == var.helm_options.timeout &&
      var.helm_options.max_history >= 0 && floor(var.helm_options.max_history) == var.helm_options.max_history
    )
    error_message = "Helm timeout must be a positive integer and max_history a nonnegative integer."
  }
}
