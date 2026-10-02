locals {
  obser_subnet_id = var.obser_subnet_id != null ? var.obser_subnet_id : try(var.subnet_ids[0], null)

  node_shapes = {
    main      = { instance_type = "t3a.medium", max_size = 2 }
    obser     = { instance_type = "t3a.medium", max_size = 2 }
    load-test = { instance_type = "t3a.large", max_size = 10 }
  }

  node_groups = {
    for group, shape in local.node_shapes : group => {
      name            = "${var.name}-${group}"
      use_name_prefix = true
      subnet_ids      = group == "obser" ? [local.obser_subnet_id] : var.subnet_ids
      instance_types  = [shape.instance_type]
      capacity_type   = "ON_DEMAND"
      min_size        = 1
      desired_size    = 1
      max_size        = shape.max_size

      ami_type                       = "AL2023_x86_64_STANDARD"
      ami_release_version            = var.node_ami_release_version
      use_latest_ami_release_version = false
      create_launch_template         = true
      use_custom_launch_template     = true
      iam_role_name                  = "${var.name}-noderole-${group}"
      iam_role_use_name_prefix       = false
      iam_role_attach_cni_policy     = try(var.eks_managed_addons["vpc-cni"].enabled, false)
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
      }
      block_device_mappings = {
        root = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 20
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }
      labels = { workload = group }
      taints = group == "main" ? {} : {
        dedicated = { key = "dedicated", value = group, effect = "NO_SCHEDULE" }
      }
      timeouts = { create = "60m", update = "60m", delete = "60m" }
      tags     = var.tags
    }
  }
}
