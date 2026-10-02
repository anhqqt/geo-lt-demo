locals {
  addons = {
    for name, addon in var.eks_managed_addons : name => {
      addon_version               = addon.version
      most_recent                 = false
      configuration_values        = jsonencode(jsondecode(addon.configuration_values))
      before_compute              = contains(["vpc-cni", "eks-pod-identity-agent"], name)
      resolve_conflicts_on_create = "NONE"
      resolve_conflicts_on_update = "OVERWRITE"
      preserve                    = false
      timeouts                    = { create = "30m", update = "30m", delete = "30m" }
      pod_identity_association = name == "aws-ebs-csi-driver" ? [{
        # Referencing the attachment keeps EBS permissions ahead of the association.
        role_arn        = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role_policy_attachment.ebs_csi[0].role}"
        service_account = "ebs-csi-controller-sa"
      }] : []
    } if addon.enabled
  }
}
