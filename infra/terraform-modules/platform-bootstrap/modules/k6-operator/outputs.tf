output "release_name" {
  value = helm_release.this.name
}

output "namespace" {
  value = helm_release.this.namespace
}

output "runner_namespace" {
  value = var.runner_namespace
}

output "runner_service_account" {
  value = "default"
}

output "workflow_role_arn" {
  value = aws_iam_role.workflow.arn
}

output "workflow_group" {
  value = local.workflow_group
}
