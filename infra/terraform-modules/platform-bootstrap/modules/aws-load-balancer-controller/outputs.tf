output "release_name" { value = helm_release.this.name }
output "namespace" { value = helm_release.this.namespace }
output "role_arn" { value = module.pod_identity.iam_role_arn }
