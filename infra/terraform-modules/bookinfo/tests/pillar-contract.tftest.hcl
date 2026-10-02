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
  enable_details                     = false
}

run "ratings_defaults" {
  command = plan
  assert {
    condition = (
      output.namespace == "bookinfo" && toset(keys(output.services)) == toset(["ratings"]) &&
      output.services.ratings.name == "ratings" &&
      output.services.ratings.port == 9080 && output.services.ratings.target_port == 9080 &&
      output.services.ratings.dns_name == "ratings.bookinfo.svc.cluster.local"
    )
    error_message = "The ratings checkpoint must expose only its internal Service reference."
  }
}

run "ratings_overrides" {
  command = plan
  variables {
    namespace = "bookinfo-preview"
    ratings = {
      context = {
        "resources.requests.cpu" = "75m"
        image                    = "mirror.example.test/ratings@sha256:aad8f7bb46664704eecd92d9ebe8563e3e41571e2301f593cc521301b14ae51d"
      }
      helm_options = { timeout = 720 }
    }
  }
  assert {
    condition     = output.services.ratings.dns_name == "ratings.bookinfo-preview.svc.cluster.local"
    error_message = "Namespace overrides must propagate through the service submodule."
  }
}

run "reject_shared_namespace" {
  command = plan
  variables {
    namespace = "monitoring"
  }
  expect_failures = [var.namespace]
}

run "reject_system_namespace" {
  command = plan
  variables {
    namespace = "kube-system"
  }
  expect_failures = [var.namespace]
}

run "reject_invalid_namespace" {
  command = plan
  variables {
    namespace = "Bookinfo/preview"
  }
  expect_failures = [var.namespace]
}

run "reject_http_endpoint" {
  command = plan
  variables {
    cluster_endpoint = "http://cluster.example.test"
  }
  expect_failures = [var.cluster_endpoint]
}

run "reject_invalid_ca" {
  command = plan
  variables {
    cluster_certificate_authority_data = "invalid-base64!"
  }
  expect_failures = [var.cluster_certificate_authority_data]
}

run "reject_null_override" {
  command = plan
  module {
    source = "./modules/ratings"
  }
  variables {
    namespace = "bookinfo"
    context   = { image = null }
  }
  expect_failures = [var.context]
}

run "reject_invalid_timeout" {
  command = plan
  module {
    source = "./modules/ratings"
  }
  variables {
    namespace    = "bookinfo"
    helm_options = { timeout = 0 }
  }
  expect_failures = [var.helm_options]
}

run "release_interface" {
  command = plan
  variables {
    ratings = {
      release_name      = "ratings-preview"
      namespace         = "bookinfo"
      repository        = "https://charts.example.test"
      chart_name        = "compatible-ratings"
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

run "ratings_installed" {
  command = apply
}

run "ratings_disabled" {
  command = plan
  variables {
    enable_ratings = false
  }
  assert {
    condition     = length(output.services) == 0 && output.namespace == "bookinfo"
    error_message = "Disabling ratings must retain the pillar namespace and omit the service reference."
  }
}

run "reject_namespace_split" {
  command = plan
  variables {
    ratings = { namespace = "different-pillar" }
  }
  expect_failures = [var.ratings]
}
