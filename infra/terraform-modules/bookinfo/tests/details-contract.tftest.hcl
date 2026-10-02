mock_provider "kubernetes" {}
mock_provider "helm" {}
mock_provider "aws" {}

variables {
  aws_region                         = "ap-southeast-1"
  enable_productpage                 = false
  cluster_name                       = "bookinfo-fixture"
  cluster_endpoint                   = "https://cluster.example.test"
  cluster_certificate_authority_data = "Zml4dHVyZS1jYQ=="
  enable_review                      = false
}

run "details_defaults" {
  command = plan
  assert {
    condition = (
      toset(keys(output.services)) == toset(["ratings", "details"]) &&
      output.services.details.name == "details" &&
      output.services.details.port == 9080 && output.services.details.target_port == 9080 &&
      output.services.details.dns_name == "details.bookinfo.svc.cluster.local"
    )
    error_message = "Details and ratings must expose separate internal Service references in one namespace."
  }
}

run "details_overrides" {
  command = plan
  variables {
    namespace = "bookinfo-preview"
    details = {
      context = {
        "resources.requests.cpu" = "75m"
        image                    = "mirror.example.test/details@sha256:a49731e1fc05d7c24a4103709f41d64180bed989b251625f4c31ba63022e303b"
      }
      helm_options = { timeout = 720 }
    }
  }
  assert {
    condition = (
      output.services.details.dns_name == "details.bookinfo-preview.svc.cluster.local" &&
      output.services.ratings.dns_name == "ratings.bookinfo-preview.svc.cluster.local"
    )
    error_message = "Both services must follow the shared namespace override."
  }
}

run "details_release_interface" {
  command = plan
  variables {
    details = {
      release_name      = "details-preview"
      namespace         = "bookinfo"
      repository        = "https://charts.example.test"
      chart_name        = "compatible-details"
      chart_version     = "0.2.0"
      context           = { "resources.requests.cpu" = "75m" }
      context_sensitive = { "environment.TEST_VALUE" = "synthetic-fixture" }
      helm_options = {
        timeout     = 720
        max_history = 3
        lint        = true
      }
    }
  }
}

run "both_services_installed" {
  command = apply
}

run "details_disabled" {
  command = plan
  variables {
    enable_details = false
  }
  assert {
    condition     = toset(keys(output.services)) == toset(["ratings"]) && output.namespace == "bookinfo"
    error_message = "Disabling details must preserve ratings and the pillar namespace."
  }
}

run "ratings_disabled_with_details" {
  command = plan
  variables {
    enable_ratings = false
  }
  assert {
    condition     = toset(keys(output.services)) == toset(["details"]) && output.namespace == "bookinfo"
    error_message = "Disabling ratings must preserve details and the pillar namespace."
  }
}

run "reject_details_namespace_split" {
  command = plan
  variables {
    details = { namespace = "different-pillar" }
  }
  expect_failures = [var.details]
}
