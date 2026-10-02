mock_provider "kubernetes" {}
mock_provider "helm" {}
mock_provider "aws" {}

variables {
  aws_region                         = "ap-southeast-1"
  cluster_name                       = "bookinfo-fixture"
  cluster_endpoint                   = "https://cluster.example.test"
  cluster_certificate_authority_data = "Zml4dHVyZS1jYQ=="
}

run "productpage_defaults" {
  command = plan
  assert {
    condition = (
      toset(keys(output.services)) == toset(["ratings", "details", "review", "productpage"]) &&
      output.services.productpage.name == "productpage" &&
      output.services.productpage.port == 80 && output.services.productpage.target_port == 9080 &&
      output.services.productpage.dns_name == "productpage.bookinfo.svc.cluster.local" &&
      output.internal_url == "http://productpage.bookinfo.svc.cluster.local/productpage"
    )
    error_message = "Productpage must expose port 80 and an internal URL alongside all three dependencies."
  }
}

run "productpage_overrides" {
  command = plan
  variables {
    namespace = "bookinfo-preview"
    productpage = {
      context = {
        "resources.requests.cpu" = "150m"
        image                    = "mirror.example.test/productpage@sha256:1e339866b782d22b063539d19c87b4682291c889e67c3d4abdea947bef917958"
      }
      helm_options = { timeout = 720 }
    }
  }
  assert {
    condition = (
      output.internal_url == "http://productpage.bookinfo-preview.svc.cluster.local/productpage" &&
      alltrue([for name, service in output.services : service.dns_name == "${name}.bookinfo-preview.svc.cluster.local"])
    )
    error_message = "The internal URL and all Service references must follow the shared namespace override."
  }
}

run "productpage_release_interface" {
  command = plan
  variables {
    productpage = {
      release_name      = "productpage-preview"
      namespace         = "bookinfo"
      repository        = "https://charts.example.test"
      chart_name        = "compatible-productpage"
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

run "four_services_installed" {
  command = apply
}

run "productpage_disabled" {
  command = plan
  variables {
    enable_productpage = false
  }
  assert {
    condition = (
      toset(keys(output.services)) == toset(["ratings", "details", "review"]) &&
      output.namespace == "bookinfo" && output.internal_url == null
    )
    error_message = "Disabling productpage must clear its URL and preserve the other services and namespace."
  }
}

run "all_services_disabled" {
  command = plan
  variables {
    enable_ratings     = false
    enable_details     = false
    enable_review      = false
    enable_productpage = false
  }
  assert {
    condition     = length(output.services) == 0 && output.namespace == "bookinfo" && output.internal_url == null
    error_message = "Disabling every service must leave only the shared namespace and no internal URL."
  }
}

run "reject_productpage_namespace_split" {
  command = plan
  variables {
    productpage = { namespace = "different-pillar" }
  }
  expect_failures = [var.productpage]
}
