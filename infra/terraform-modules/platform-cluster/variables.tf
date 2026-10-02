variable "name" {
  description = "Base name for the EKS cluster, managed node groups and cluster-owned IAM roles."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_-]{0,44}$", var.name))
    error_message = "Use 1 to 45 letters, numbers, underscores or hyphens so the -noderole-load-test suffix fits the IAM role limit."
  }
}

variable "aws_region" {
  description = "AWS commercial region containing the existing VPC."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^(af|ap|ca|eu|il|me|mx|sa|us)-(central|east|north|northeast|northwest|south|southeast|southwest|west)-[0-9]+$", var.aws_region))
    error_message = "Use an AWS commercial region name."
  }
}

variable "kubernetes_version" {
  description = "EKS minor version from the module release; override only with a compatible AMI and add-on set."
  type        = string
  default     = "1.36"
  nullable    = false
  validation {
    condition     = can(regex("^1\\.[0-9]+$", var.kubernetes_version))
    error_message = "Pin a Kubernetes minor version such as 1.36."
  }
}

variable "vpc_id" {
  description = "Existing VPC owned by the regional core unit."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "Supply an existing VPC ID."
  }
}

variable "subnet_ids" {
  description = "Existing private subnet IDs in at least two AZs, in the caller's preferred order."
  type        = list(string)
  nullable    = false
  validation {
    condition = (
      length(var.subnet_ids) >= 2 &&
      length(distinct(var.subnet_ids)) == length(var.subnet_ids) &&
      alltrue([for id in var.subnet_ids : can(regex("^subnet-[0-9a-f]+$", id))])
    )
    error_message = "Supply at least two distinct private subnet IDs."
  }
}

variable "obser_subnet_id" {
  description = "Private subnet for obser nodes; null selects the first subnet_ids entry."
  type        = string
  default     = null
  validation {
    condition     = var.obser_subnet_id == null ? true : contains(var.subnet_ids, var.obser_subnet_id)
    error_message = "The obser subnet must be one of subnet_ids, or null to use the first entry."
  }
}

variable "node_ami_release_version" {
  description = "Pinned AL2023 x86-64 standard AMI release supplied by the module, with an optional caller override."
  type        = string
  default     = "1.36.4-20260923"
  nullable    = false
  validation {
    condition     = can(regex("^${replace(var.kubernetes_version, ".", "\\.")}\\.[0-9]+-[0-9]{8}$", var.node_ami_release_version))
    error_message = "Pin an EKS AMI release matching the Kubernetes minor, for example 1.36.0-20260101."
  }
}

variable "eks_managed_addons" {
  description = "Complete desired add-on map. Omit this input to use the module bundle; an explicit map replaces the entire default."
  type = map(object({
    enabled              = optional(bool, true)
    version              = string
    configuration_values = optional(string, "{}")
  }))
  default = {
    vpc-cni = {
      enabled              = true
      version              = "v1.22.4-eksbuild.3"
      configuration_values = <<-JSON
        {"tolerations":[{"operator":"Exists"}]}
      JSON
    }
    kube-proxy = {
      enabled              = true
      version              = "v1.36.0-eksbuild.25"
      configuration_values = "{}"
    }
    coredns = {
      enabled              = true
      version              = "v1.14.3-eksbuild.23"
      configuration_values = <<-JSON
        {"nodeSelector":{"workload":"main"}}
      JSON
    }
    eks-pod-identity-agent = {
      enabled              = true
      version              = "v1.3.10-eksbuild.3"
      configuration_values = <<-JSON
        {"tolerations":[{"operator":"Exists"}]}
      JSON
    }
    aws-ebs-csi-driver = {
      enabled              = true
      version              = "v1.66.0-eksbuild.1"
      configuration_values = <<-JSON
        {
          "controller": {"nodeSelector": {"workload": "main"}},
          "node": {"enableWindows": false, "tolerateAllTaints": true},
          "defaultStorageClass": {"enabled": true}
        }
      JSON
    }
  }
  nullable = false

  validation {
    condition     = length(setsubtract(keys(var.eks_managed_addons), ["vpc-cni", "kube-proxy", "coredns", "eks-pod-identity-agent", "aws-ebs-csi-driver"])) == 0
    error_message = "Override only vpc-cni, kube-proxy, coredns, eks-pod-identity-agent or aws-ebs-csi-driver."
  }

  validation {
    condition     = alltrue([for addon in values(var.eks_managed_addons) : addon != null])
    error_message = "Each add-on entry must be an object, not null."
  }

  validation {
    condition     = alltrue([for addon in values(var.eks_managed_addons) : can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+-eksbuild\\.[0-9]+$", addon.version))])
    error_message = "Every supplied add-on needs an explicit vX.Y.Z-eksbuild.N version."
  }

  validation {
    condition     = alltrue([for addon in values(var.eks_managed_addons) : can(keys(jsondecode(addon.configuration_values)))])
    error_message = "configuration_values must be a JSON object string."
  }

  validation {
    condition     = !try(var.eks_managed_addons["aws-ebs-csi-driver"].enabled, false) || try(var.eks_managed_addons["eks-pod-identity-agent"].enabled, false)
    error_message = "Enable eks-pod-identity-agent while aws-ebs-csi-driver uses its dedicated Pod Identity role."
  }
}

variable "tags" {
  description = "Common project, environment and ownership tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
