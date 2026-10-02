output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_arn" {
  value = module.eks.cluster_arn
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  value = module.eks.node_security_group_id
}

output "node_iam_role_arns" {
  value = { for group, node in module.eks.eks_managed_node_groups : group => node.iam_role_arn }
}

output "node_group_names" {
  value = { for group, node in module.eks.eks_managed_node_groups : group => split(":", node.node_group_id)[1] }
}

output "node_group_autoscaling_group_names" {
  value = { for group, node in module.eks.eks_managed_node_groups : group => node.node_group_autoscaling_group_names }
}

output "monitoring_az" {
  value = data.aws_subnet.obser.availability_zone
}

output "monitoring_subnet_id" {
  value = local.obser_subnet_id
}

output "storage_class_name" {
  value = try(var.eks_managed_addons["aws-ebs-csi-driver"].enabled, false) && try(jsondecode(var.eks_managed_addons["aws-ebs-csi-driver"].configuration_values).defaultStorageClass.enabled, false) ? "ebs-csi-default-sc" : null
}

output "ebs_csi_role_arn" {
  value = one(aws_iam_role.ebs_csi[*].arn)
}

output "addon_versions" {
  value = tomap({ for name, addon in var.eks_managed_addons : name => addon.version if addon.enabled })
}
