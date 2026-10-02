# These inputs exercise the real variable checks without a provider or AWS calls.
variables {
  name       = "geo-lt-dev-apse1-main"
  aws_region = "ap-southeast-1"
  vpc_id     = "vpc-0123456789abcdef0"
  subnet_ids = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]

}

run "valid_contract" {
  command = plan
  assert {
    condition = alltrue([
      for group, node in output.node_configuration :
      node.name == "${var.name}-${group}" &&
      node.iam_role_name == "${var.name}-noderole-${group}" &&
      node.use_name_prefix && !node.iam_role_use_name_prefix
    ])
    error_message = "Node-group name prefixes must derive from the cluster name and group; IAM role names must use the exact <name>-noderole-<group> form."
  }
  assert {
    condition = (
      toset(keys(output.addon_configuration)) == toset(["vpc-cni", "kube-proxy", "coredns", "eks-pod-identity-agent", "aws-ebs-csi-driver"]) &&
      alltrue([for addon in values(output.addon_configuration) : addon.enabled && can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+-eksbuild\\.[0-9]+$", addon.version))]) &&
      jsondecode(output.addon_configuration.coredns.configuration_values).nodeSelector.workload == "main" &&
      jsondecode(output.addon_configuration["aws-ebs-csi-driver"].configuration_values).defaultStorageClass.enabled
    )
    error_message = "No version or add-on inputs must install all five pinned defaults with the storage and controller settings."
  }
  assert {
    condition = alltrue([
      for group, node in output.node_configuration :
      node.min_size == 1 && node.desired_size == 1 &&
      node.max_size == (group == "load-test" ? 10 : 2) &&
      node.instance_types == [group == "load-test" ? "t3a.large" : "t3a.medium"] &&
      node.labels.workload == group && node.iam_role_attach_cni_policy &&
      node.ami_release_version == var.node_ami_release_version &&
      node.use_latest_ami_release_version == false
    ])
    error_message = "Node groups must retain the accepted bounds, instance types, placement labels and AMI pin."
  }
  assert {
    condition = (
      length(output.node_configuration.main.taints) == 0 &&
      output.node_configuration.obser.taints.dedicated == { key = "dedicated", value = "obser", effect = "NO_SCHEDULE" } &&
      output.node_configuration["load-test"].taints.dedicated == { key = "dedicated", value = "load-test", effect = "NO_SCHEDULE" }
    )
    error_message = "Only the two dedicated groups may carry their exact scheduling taints."
  }
  assert {
    condition = (
      tolist(output.node_configuration.obser.subnet_ids) == tolist([var.subnet_ids[0]]) &&
      tolist(output.node_configuration.main.subnet_ids) == var.subnet_ids &&
      tolist(output.node_configuration["load-test"].subnet_ids) == var.subnet_ids
    )
    error_message = "Monitoring must remain in its selected AZ; other nodes use both private subnets."
  }
}

run "override_obser_subnet" {
  command = plan
  variables {
    obser_subnet_id = "subnet-0123456789abcdef1"
  }
  assert {
    condition = (
      tolist(output.node_configuration.obser.subnet_ids) == tolist([var.obser_subnet_id]) &&
      tolist(output.node_configuration.main.subnet_ids) == var.subnet_ids &&
      tolist(output.node_configuration["load-test"].subnet_ids) == var.subnet_ids
    )
    error_message = "An obser override must affect only the monitoring group."
  }
}

run "default_obser_follows_subnet_order" {
  command = plan
  variables {
    subnet_ids = ["subnet-0123456789abcdef1", "subnet-0123456789abcdef0"]
  }
  assert {
    condition     = tolist(output.node_configuration.obser.subnet_ids) == tolist(["subnet-0123456789abcdef1"])
    error_message = "Without an override, obser must use the first supplied subnet."
  }
}

run "node_roles_are_distinct_between_clusters" {
  command = plan
  variables {
    name = "geo-lt-dev-apse1-secondary"
  }
  assert {
    condition = alltrue([
      for group, node in output.node_configuration :
      node.name != run.valid_contract.node_configuration[group].name &&
      node.iam_role_name != run.valid_contract.node_configuration[group].iam_role_name &&
      length(node.iam_role_name) <= 64
    ])
    error_message = "Distinct cluster names must produce distinct node-group name prefixes and node IAM role names."
  }
}

run "reject_unlisted_obser_subnet" {
  command = plan
  variables {
    obser_subnet_id = "subnet-0123456789abcdef2"
  }
  expect_failures = [var.obser_subnet_id]
}

run "reject_duplicated_subnets" {
  command = plan
  variables {
    subnet_ids = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef0"]
  }
  expect_failures = [var.subnet_ids]
}

run "reject_empty_subnets" {
  command = plan
  variables {
    subnet_ids = []
  }
  expect_failures = [var.subnet_ids]
}

run "reject_single_subnet" {
  command = plan
  variables {
    subnet_ids = ["subnet-0123456789abcdef0"]
  }
  expect_failures = [var.subnet_ids]
}

run "reject_oversized_derived_role_name" {
  command = plan
  variables {
    name = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }
  expect_failures = [var.name]
}

run "accept_longest_cluster_name" {
  command = plan
  variables {
    name = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }
  assert {
    condition = (
      length(output.node_configuration["load-test"].iam_role_name) == 64 &&
      alltrue([for node in values(output.node_configuration) : length(node.iam_role_name) <= 64])
    )
    error_message = "The longest supported base name must fit every derived node IAM role without truncation."
  }
}

run "reject_unset_ami_pin" {
  command = plan
  variables { node_ami_release_version = "" }
  expect_failures = [var.node_ami_release_version]
}

run "reject_empty_addon_version" {
  command = plan
  variables {
    eks_managed_addons = { coredns = { enabled = true, version = "" } }
  }
  expect_failures = [var.eks_managed_addons]
}

run "reject_non_object_addon_configuration" {
  command = plan
  variables {
    eks_managed_addons = { coredns = { enabled = true, version = "v1.0.0-eksbuild.1", configuration_values = "[]" } }
  }
  expect_failures = [var.eks_managed_addons]
}

run "reject_omitted_pod_identity_agent" {
  command = plan
  variables {
    eks_managed_addons = { aws-ebs-csi-driver = { version = "v1.66.0-eksbuild.1" } }
  }
  expect_failures = [var.eks_managed_addons]
}

run "reject_disabled_pod_identity_agent" {
  command = plan
  variables {
    eks_managed_addons = {
      aws-ebs-csi-driver     = { version = "v1.66.0-eksbuild.1" }
      eks-pod-identity-agent = { enabled = false, version = "v1.3.10-eksbuild.3" }
    }
  }
  expect_failures = [var.eks_managed_addons]
}

run "four_entries_omit_ebs" {
  command = plan
  variables {
    eks_managed_addons = {
      for name, addon in run.valid_contract.addon_configuration : name => addon if name != "aws-ebs-csi-driver"
    }
  }
  assert {
    condition = (
      length(output.addon_configuration) == 4 &&
      !contains(keys(output.addon_configuration), "aws-ebs-csi-driver") &&
      alltrue([for addon in values(output.addon_configuration) : addon.enabled]) &&
      alltrue([for node in values(output.node_configuration) : node.iam_role_attach_cni_policy])
    )
    error_message = "An explicit four-entry map must omit EBS while retaining the four supplied add-ons and CNI permissions."
  }
}

run "empty_map_disables_all" {
  command = plan
  variables { eks_managed_addons = {} }
  assert {
    condition     = length(output.addon_configuration) == 0 && alltrue([for node in values(output.node_configuration) : !node.iam_role_attach_cni_policy])
    error_message = "An explicit empty map must disable all add-ons and CNI permissions."
  }
}

run "disabled_cni_removes_node_permissions" {
  command = plan
  variables {
    eks_managed_addons = {
      for name, addon in run.valid_contract.addon_configuration : name => merge(addon, { enabled = name != "vpc-cni" })
    }
  }
  assert {
    condition = (
      alltrue([for node in values(output.node_configuration) : !node.iam_role_attach_cni_policy]) &&
      alltrue([for name, addon in output.addon_configuration : addon.enabled if name != "vpc-cni"])
    )
    error_message = "An explicit disabled CNI entry must remove its node permissions while preserving other supplied entries."
  }
}

run "omitted_cni_removes_node_permissions" {
  command = plan
  variables {
    eks_managed_addons = {
      for name, addon in run.valid_contract.addon_configuration : name => addon if name != "vpc-cni"
    }
  }
  assert {
    condition     = length(output.addon_configuration) == 4 && alltrue([for node in values(output.node_configuration) : !node.iam_role_attach_cni_policy])
    error_message = "Omitting CNI must remove its node permissions without restoring the default entry."
  }
}

run "single_entry_replaces_bundle" {
  command = plan
  variables {
    eks_managed_addons = { coredns = { version = "v9.9.9-eksbuild.1" } }
  }
  assert {
    condition = (
      length(output.addon_configuration) == 1 && output.addon_configuration.coredns.enabled &&
      output.addon_configuration.coredns.version == "v9.9.9-eksbuild.1" &&
      output.addon_configuration.coredns.configuration_values == "{}"
    )
    error_message = "A one-entry override must keep only that entry, without inheriting the module configuration or other add-ons."
  }
}

run "complete_map_preserves_bundle" {
  command = plan
  variables { eks_managed_addons = run.valid_contract.addon_configuration }
  assert {
    condition     = output.addon_configuration == run.valid_contract.addon_configuration
    error_message = "An explicit complete map must use exactly the supplied entries and configuration."
  }
}

run "reject_null_addon_version" {
  command = plan
  variables { eks_managed_addons = { coredns = { version = null } } }
  expect_failures = [var.eks_managed_addons]
}

run "disable_ebs_and_agent" {
  command = plan
  variables {
    eks_managed_addons = {
      aws-ebs-csi-driver     = { enabled = false, version = "v1.66.0-eksbuild.1" }
      eks-pod-identity-agent = { enabled = false, version = "v1.3.10-eksbuild.3" }
    }
  }
}

run "reject_null_addon_entry" {
  command = plan
  variables {
    eks_managed_addons = { coredns = null }
  }
  expect_failures = [var.eks_managed_addons]
}

run "reject_unknown_addon" {
  command = plan
  variables { eks_managed_addons = { aws-ebs-csi-drivr = { enabled = false, version = "v1.0.0-eksbuild.1" } } }
  expect_failures = [var.eks_managed_addons]
}

run "compatible_kubernetes_and_ami_override" {
  command = plan
  variables {
    kubernetes_version       = "1.35"
    node_ami_release_version = "1.35.0-20260101"
  }
  assert {
    condition     = alltrue([for node in values(output.node_configuration) : node.ami_release_version == var.node_ami_release_version])
    error_message = "Node groups must use the caller's explicit matching AMI override."
  }
}

run "reject_mismatched_kubernetes_and_ami" {
  command = plan
  variables { node_ami_release_version = "1.34.0-20260101" }
  expect_failures = [var.node_ami_release_version]
}
