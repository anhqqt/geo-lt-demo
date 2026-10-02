locals {
  workflow_group = "geo-lt:load-test-runs"
}

resource "aws_eks_access_entry" "workflow" {
  cluster_name      = var.cluster_name
  principal_arn     = aws_iam_role.workflow.arn
  type              = "STANDARD"
  kubernetes_groups = [local.workflow_group]
  tags              = var.tags
}
