# Cluster and workflow access

variable "cluster_name" {
  description = "Existing EKS cluster name used for the workflow role and access entry."
  type        = string
  nullable    = false
}

variable "cluster_arn" {
  description = "Existing EKS cluster ARN allowed by the workflow policy."
  type        = string
  nullable    = false
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub Actions OIDC provider ARN from the identity unit."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:aws(-[a-z]+)?:iam::[0-9]{12}:oidc-provider/token[.]actions[.]githubusercontent[.]com$", var.github_oidc_provider_arn))
    error_message = "Use the existing IAM OIDC provider for token.actions.githubusercontent.com."
  }
}

variable "github_oidc_subject" {
  description = "Verified exact repository default-branch subject, including immutable IDs when enabled."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^repo:[A-Za-z0-9_.-]+(@[0-9]+)?/[A-Za-z0-9_.-]+(@[0-9]+)?:ref:refs/heads/[^*?: \\t\\r\\n]+$", var.github_oidc_subject))
    error_message = "Use one exact repository branch subject; wildcards, PR, tag and environment subjects are not allowed."
  }
}

variable "tags" {
  description = "Tags applied to the workflow IAM role and EKS access entry."
  type        = map(string)
  default     = {}
  nullable    = false
}

# Helm release

variable "release_name" {
  description = "Name of the Helm release."
  type        = string
  default     = "k6-operator"
  nullable    = false
}

variable "namespace" {
  description = "Namespace for the k6 Operator release."
  type        = string
  default     = "k6-operator"
  nullable    = false
}

variable "runner_namespace" {
  description = "Namespace for TestRuns and generator Pods; set it equal to namespace to share the Operator namespace."
  type        = string
  default     = "k6-runners"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.runner_namespace))
    error_message = "Use a valid Kubernetes namespace name."
  }
}

variable "repository" {
  description = "Helm repository containing the controller chart."
  type        = string
  default     = "https://grafana.github.io/helm-charts"
  nullable    = false
}

variable "chart_name" {
  description = "Name of the controller Helm chart."
  type        = string
  default     = "k6-operator"
  nullable    = false
}

variable "chart_version" {
  description = "Exact version of the k6 Operator Helm chart."
  type        = string
  default     = "4.6.0"
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
    condition = alltrue([
      for key in concat(keys(var.context), keys(var.context_sensitive)) :
      !can(regex("^(namespace|rbac|service|metrics)([.\\[]|$)|^manager[.](serviceAccount|env|envFrom)([.\\[]|$)", key))
    ])
    error_message = "Keep namespace ownership, chart RBAC, controller ServiceAccount and watch scope in the module template."
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
