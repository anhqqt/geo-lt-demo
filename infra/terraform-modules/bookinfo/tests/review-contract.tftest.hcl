mock_provider "kubernetes" {}
mock_provider "helm" {}
mock_provider "aws" {}

variables {
  aws_region                         = "ap-southeast-1"
  enable_productpage                 = false
  cluster_name                       = "bookinfo-fixture"
  cluster_endpoint                   = "https://cluster.example.test"
  cluster_certificate_authority_data = "Zml4dHVyZS1jYQ=="
}

run "review_defaults" {
  command = plan
  assert {
    condition = (
      toset(keys(output.services)) == toset(["ratings", "details", "review"]) &&
      output.services.review.name == "review" &&
      output.services.review.port == 9080 && output.services.review.target_port == 9080 &&
      output.services.review.dns_name == "review.bookinfo.svc.cluster.local"
    )
    error_message = "All three services must expose separate internal Service references in one namespace."
  }
}

run "review_overrides" {
  command = plan
  variables {
    namespace = "bookinfo-preview"
    review = {
      context = {
        "resources.requests.cpu" = "300m"
        image                    = "mirror.example.test/review@sha256:09b92ca16738b5bded2ae66ba0a4b21d32e86d8b6ddb34331abfe1179d8c6298"
      }
      helm_options = { timeout = 720 }
    }
  }
  assert {
    condition = (
      output.services.review.dns_name == "review.bookinfo-preview.svc.cluster.local" &&
      output.services.ratings.dns_name == "ratings.bookinfo-preview.svc.cluster.local" &&
      output.services.details.dns_name == "details.bookinfo-preview.svc.cluster.local"
    )
    error_message = "All services must follow the shared namespace override."
  }
}

run "review_release_interface" {
  command = plan
  variables {
    review = {
      release_name      = "review-preview"
      namespace         = "bookinfo"
      repository        = "https://charts.example.test"
      chart_name        = "compatible-review"
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

run "three_services_installed" {
  command = apply
}

run "review_disabled" {
  command = plan
  variables {
    enable_review = false
  }
  assert {
    condition     = toset(keys(output.services)) == toset(["ratings", "details"]) && output.namespace == "bookinfo"
    error_message = "Disabling review must preserve ratings, details and the pillar namespace."
  }
}

run "ratings_disabled_with_review" {
  command = plan
  variables {
    enable_ratings = false
  }
  assert {
    condition     = toset(keys(output.services)) == toset(["details", "review"]) && output.namespace == "bookinfo"
    error_message = "Disabling ratings must preserve details, review and the pillar namespace."
  }
}

run "reject_review_namespace_split" {
  command = plan
  variables {
    review = { namespace = "different-pillar" }
  }
  expect_failures = [var.review]
}
