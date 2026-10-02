mock_provider "kubernetes" {}
mock_provider "helm" {}
mock_provider "aws" {}

variables {
  aws_region                         = "ap-southeast-1"
  cluster_name                       = "bookinfo-fixture"
  cluster_endpoint                   = "https://cluster.example.test"
  cluster_certificate_authority_data = "Zml4dHVyZS1jYQ=="
  productpage                        = { "ingress_enable" : true, "ingress_host" : "bookinfo.demo.anhquach.dev", "ingress_annotations" : { "alb.ingress.kubernetes.io/group.name" : "geo-lt-dev-apse1", "alb.ingress.kubernetes.io/load-balancer-name" : "geo-lt-dev-apse1", "alb.ingress.kubernetes.io/subnets" : "subnet-0123456789abcdef0,subnet-0123456789abcdef1", "alb.ingress.kubernetes.io/certificate-arn" : "arn:aws:acm:ap-southeast-1:111122223333:certificate/11111111-2222-3333-4444-555555555555" } }
}

run "exposure_enabled" {
  command = plan
  assert {
    condition = (
      output.public_url == "https://bookinfo.demo.anhquach.dev/productpage" &&
      output.ingress_name == "bookinfo" &&
      output.internal_url == "http://productpage.bookinfo.svc.cluster.local/productpage"
    )
    error_message = "Public exposure must preserve the internal URL and expose configured HTTPS references."
  }
}

run "exposure_override" {
  command = plan
  variables {
    namespace   = "bookinfo-preview"
    productpage = { "ingress_enable" : true, "ingress_host" : "preview.demo.anhquach.dev", "ingress_annotations" : { "alb.ingress.kubernetes.io/group.name" : "geo-lt-dev-apse1", "alb.ingress.kubernetes.io/load-balancer-name" : "geo-lt-dev-apse1", "alb.ingress.kubernetes.io/subnets" : "subnet-0123456789abcdef0,subnet-0123456789abcdef1", "alb.ingress.kubernetes.io/certificate-arn" : "arn:aws:acm:ap-southeast-1:111122223333:certificate/11111111-2222-3333-4444-555555555555", "alb.ingress.kubernetes.io/healthcheck-path" : "/custom-health" } }
  }
  assert {
    condition     = output.public_url == "https://preview.demo.anhquach.dev/productpage"
    error_message = "The public URL must follow the configured host."
  }
}

run "exposure_installed" {
  command = apply
}

run "exposure_disabled" {
  command = plan
  variables {
    productpage = { "ingress_enable" : false, "ingress_host" : "bookinfo.demo.anhquach.dev", "ingress_annotations" : { "alb.ingress.kubernetes.io/group.name" : "geo-lt-dev-apse1", "alb.ingress.kubernetes.io/load-balancer-name" : "geo-lt-dev-apse1", "alb.ingress.kubernetes.io/subnets" : "subnet-0123456789abcdef0,subnet-0123456789abcdef1", "alb.ingress.kubernetes.io/certificate-arn" : "arn:aws:acm:ap-southeast-1:111122223333:certificate/11111111-2222-3333-4444-555555555555" } }
  }
  assert {
    condition = (
      output.public_url == null && output.ingress_name == null &&
      output.internal_url == "http://productpage.bookinfo.svc.cluster.local/productpage" && length(output.services) == 4
    )
    error_message = "Disabling Ingress must clear only public references and preserve all internal services."
  }
}

run "exposed_productpage_disabled" {
  command = plan
  variables { enable_productpage = false }
  assert {
    condition     = output.public_url == null && output.ingress_name == null && output.internal_url == null
    error_message = "Disabling productpage must clear its public and internal references."
  }
}

run "reject_invalid_host" {
  command = plan
  module { source = "./modules/productpage" }
  variables {
    ingress_enable      = true
    ingress_host        = "https://bookinfo.demo.anhquach.dev/x"
    ingress_annotations = { "alb.ingress.kubernetes.io/group.name" : "geo-lt-dev-apse1", "alb.ingress.kubernetes.io/load-balancer-name" : "geo-lt-dev-apse1", "alb.ingress.kubernetes.io/subnets" : "subnet-0123456789abcdef0,subnet-0123456789abcdef1", "alb.ingress.kubernetes.io/certificate-arn" : "arn:aws:acm:ap-southeast-1:111122223333:certificate/11111111-2222-3333-4444-555555555555" }
  }
  expect_failures = [var.ingress_host]
}

run "reject_wildcard_host" {
  command = plan
  module { source = "./modules/productpage" }
  variables {
    ingress_enable      = true
    ingress_host        = "*.demo.anhquach.dev"
    ingress_annotations = { "alb.ingress.kubernetes.io/group.name" : "geo-lt-dev-apse1", "alb.ingress.kubernetes.io/load-balancer-name" : "geo-lt-dev-apse1", "alb.ingress.kubernetes.io/subnets" : "subnet-0123456789abcdef0,subnet-0123456789abcdef1", "alb.ingress.kubernetes.io/certificate-arn" : "arn:aws:acm:ap-southeast-1:111122223333:certificate/11111111-2222-3333-4444-555555555555" }
  }
  expect_failures = [var.ingress_host]
}

run "reject_long_dns_label" {
  command = plan
  module { source = "./modules/productpage" }
  variables {
    ingress_enable      = true
    ingress_host        = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.example.test"
    ingress_annotations = { "alb.ingress.kubernetes.io/group.name" : "geo-lt-dev-apse1", "alb.ingress.kubernetes.io/load-balancer-name" : "geo-lt-dev-apse1", "alb.ingress.kubernetes.io/subnets" : "subnet-0123456789abcdef0,subnet-0123456789abcdef1", "alb.ingress.kubernetes.io/certificate-arn" : "arn:aws:acm:ap-southeast-1:111122223333:certificate/11111111-2222-3333-4444-555555555555" }
  }
  expect_failures = [var.ingress_host]
}

run "ingress_annotation_defaults" {
  command = plan
  module { source = "./modules/productpage" }
  variables {
    ingress_enable = true
    ingress_host   = "bookinfo.demo.anhquach.dev"
  }
  assert {
    condition = (
      yamldecode(helm_release.this.values[0]).ingress.annotations["alb.ingress.kubernetes.io/scheme"] == "internet-facing" &&
      yamldecode(helm_release.this.values[0]).ingress.annotations["alb.ingress.kubernetes.io/healthcheck-path"] == "/health"
    )
    error_message = "Empty ingress_annotations must use the built-in defaults without requiring shared ALB settings."
  }
}

run "reject_null_annotation" {
  command = plan
  module { source = "./modules/productpage" }
  variables {
    ingress_enable      = true
    ingress_host        = "bookinfo.demo.anhquach.dev"
    ingress_annotations = { "alb.ingress.kubernetes.io/group.name" : "geo-lt-dev-apse1", "alb.ingress.kubernetes.io/load-balancer-name" : "geo-lt-dev-apse1", "alb.ingress.kubernetes.io/subnets" : "subnet-0123456789abcdef0,subnet-0123456789abcdef1", "alb.ingress.kubernetes.io/certificate-arn" : "arn:aws:acm:ap-southeast-1:111122223333:certificate/11111111-2222-3333-4444-555555555555", "example.test/flag" : null }
  }
  expect_failures = [var.ingress_annotations]
}
