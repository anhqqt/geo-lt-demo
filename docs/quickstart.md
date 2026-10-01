# TL;DR: deploy and run your own demo

Use your own AWS account and GitHub repository. Before starting, install the [required tools](setup.md#tools), plus `jq`, and have access to a subdomain's parent DNS.

Run the blocks in order in one Bash terminal. Replace the sample values and stop if a command fails. AWS resources keep costing money until you [remove them](setup.md#remove-the-foundation). A fresh grouped Platform deployment has [not been exercised](setup.md#3-platform-cluster-bootstrap-and-bookinfo).

## 1. Create your repository

Create a new GitHub repository and copy this project into it, using `main` as the default branch. Replace `YOUR-OWNER/YOUR-REPO` below with your repository, for example `anhqqt/geo-lt-demo`.

Open your local checkout at the repository root and sign in to GitHub CLI before continuing.

## 2. Set your AWS account, network, DNS and OIDC trust

Use your normal AWS CLI login method first. With tfenv and tgenv installed:

```bash
tfenv install 1.16.4 && tfenv use 1.16.4
tgenv install 1.1.6 && tgenv use 1.1.6
export AWS_PROFILE=your-dev-profile
export AWS_ACCOUNT_ID=123456789012
export AWS_REGION=ap-southeast-1
aws sts get-caller-identity
```

Confirm the AWS account and non-root maintainer identity. Use that identity for all applies.

For a new repository using GitHub's [default OIDC subject with IDs](https://docs.github.com/en/actions/reference/security/oidc#immutable-subject-claims), print the subject for branch `main`:

```bash
gh api "repos/YOUR-OWNER/YOUR-REPO" \
  --jq '"repo:\(.owner.login)@\(.owner.id)/\(.name)@\(.id):ref:refs/heads/main"'
```

Edit these settings. The examples belong to `anhqqt/geo-lt-demo`; use your own domain, branch subject and network ranges.

| File | Field | Example value |
|---|---|---|
| `infra/live/dev/env.hcl` | `locals.dns_zone_name` | `"demo.anhquach.dev"` |
| `infra/live/dev/ap-southeast-1/platform/bootstrap/terragrunt.hcl` | `inputs.k6_operator.github_oidc_subject` | `"repo:anhqqt@61163704/geo-lt-demo@1398407508:ref:refs/heads/main"` |
| `infra/live/dev/ap-southeast-1/region.hcl` | `locals.vpc_cidr` | `"10.40.0.0/16"` |
| `infra/live/dev/ap-southeast-1/region.hcl` | `locals.public_subnet_cidrs` | `["10.40.0.0/24", "10.40.1.0/24"]` |
| `infra/live/dev/ap-southeast-1/region.hcl` | `locals.private_subnet_cidrs` | `["10.40.16.0/20", "10.40.32.0/20"]` |

Review and publish your configuration changes:

```bash
git diff -- infra/live/dev/env.hcl \
  infra/live/dev/ap-southeast-1/region.hcl \
  infra/live/dev/ap-southeast-1/platform/bootstrap/terragrunt.hcl
git add infra/live/dev/env.hcl \
  infra/live/dev/ap-southeast-1/region.hcl \
  infra/live/dev/ap-southeast-1/platform/bootstrap/terragrunt.hcl
git commit -m "Configure demo environment"
git push origin main
```

## 3. Deploy the three layers

**Global:** bootstrap state and review both unit plans.

```bash
terragrunt --working-dir infra/live/dev/global/identity backend bootstrap
cd infra/live/dev/global
terragrunt run --all -- plan -out=setup.tfplan
terragrunt run --all -- apply setup.tfplan
terragrunt --working-dir dns run -- output -json name_servers
```

**Before Core:** add all four nameservers as an NS record for your subdomain at its parent DNS provider. Replace `demo.example.com` below with your domain and wait until the public answers match:

```bash
dig +trace NS demo.example.com
dig @1.1.1.1 +short NS demo.example.com
```

**Core:** VPC and certificate

```bash
cd ../ap-southeast-1/core
terragrunt run --all -- plan -out=setup.tfplan
terragrunt run --all -- apply setup.tfplan
```

**Before Platform:** wait for the certificate to be `ISSUED`. Check that the regional EC2 Standard On-Demand quota has at least 6 vCPUs free for the initial nodes; see [quota and deployment notes](setup.md#3-platform-cluster-bootstrap-and-bookinfo).

```bash
aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A --query Quota.Value --output text
```

Once the quota is sufficient, review the Platform configuration and queue, then apply cluster → bootstrap → Bookinfo. The underlying Terraform applies are auto-approved.

```bash
cd ../platform
terragrunt run --all -- apply
```

## 4. Connect your deployment to GitHub Actions

Stay in the Platform directory. Read the outputs and confirm that nodes and Pods are ready.

```bash
CLUSTER_NAME="$(terragrunt --working-dir cluster run -- output -raw cluster_name)"
K6_CONFIG="$(terragrunt --working-dir bootstrap run -- output -json k6_operator)"
MONITORING_CONFIG="$(terragrunt --working-dir bootstrap run -- output -json kube_prometheus_stack)"
REPOSITORY_INFO="$(gh api "repos/YOUR-OWNER/YOUR-REPO")"
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"
kubectl get nodes -L workload
kubectl get pods -A
```

Follow [setup checks](setup.md#verify-the-setup) for Bookinfo and the Grafana Viewer login. Then set the twelve Repository Variables from the outputs above:

```bash
gh variable set AWS_ACCOUNT_ID --repo "YOUR-OWNER/YOUR-REPO" --body "$AWS_ACCOUNT_ID"
gh variable set AWS_REGION --repo "YOUR-OWNER/YOUR-REPO" --body "$AWS_REGION"
gh variable set AWS_CLUSTER_NAME --repo "YOUR-OWNER/YOUR-REPO" --body "$CLUSTER_NAME"
gh variable set AWS_ROLE_ARN --repo "YOUR-OWNER/YOUR-REPO" --body "$(printf '%s' "$K6_CONFIG" | jq -er '.workflow_role_arn')"
gh variable set LOAD_TEST_NAMESPACE --repo "YOUR-OWNER/YOUR-REPO" --body "$(printf '%s' "$K6_CONFIG" | jq -er '.runner_namespace')"
gh variable set LOAD_TEST_SERVICE_ACCOUNT --repo "YOUR-OWNER/YOUR-REPO" --body "$(printf '%s' "$K6_CONFIG" | jq -er '.runner_service_account')"
gh variable set PROMETHEUS_REMOTE_WRITE_URL --repo "YOUR-OWNER/YOUR-REPO" --body "$(printf '%s' "$MONITORING_CONFIG" | jq -er '.remote_write_url')"
gh variable set GRAFANA_URL --repo "YOUR-OWNER/YOUR-REPO" --body "$(printf '%s' "$MONITORING_CONFIG" | jq -er '.grafana_url')"
gh variable set LOAD_TEST_REPOSITORY --repo "YOUR-OWNER/YOUR-REPO" --body "$(printf '%s' "$REPOSITORY_INFO" | jq -er '.full_name')"
gh variable set LOAD_TEST_REPOSITORY_ID --repo "YOUR-OWNER/YOUR-REPO" --body "$(printf '%s' "$REPOSITORY_INFO" | jq -er '.id')"
gh variable set LOAD_TEST_REPOSITORY_OWNER_ID --repo "YOUR-OWNER/YOUR-REPO" --body "$(printf '%s' "$REPOSITORY_INFO" | jq -er '.owner.id')"
gh variable set LOAD_TEST_DEFAULT_BRANCH --repo "YOUR-OWNER/YOUR-REPO" --body "$(printf '%s' "$REPOSITORY_INFO" | jq -er '.default_branch')"
```

## 5. Verify access, then run a test

Enable Actions in your repository if needed. Keep branch-based OIDC trust; do not attach a GitHub Environment. Run the access check, then use its ID in `gh run watch`:

```bash
gh workflow run verify-load-test-access.yml --repo "YOUR-OWNER/YOUR-REPO" --ref main
gh run list --repo "YOUR-OWNER/YOUR-REPO" --workflow verify-load-test-access.yml --limit 5
gh run watch ACCESS_RUN_ID --repo "YOUR-OWNER/YOUR-REPO" --exit-status
```

The check takes over 15 minutes because it verifies token renewal. After it passes, run **20 total VUs for 60 seconds across two runners**:

```bash
gh workflow run load-test.yml --repo "YOUR-OWNER/YOUR-REPO" --ref main \
  -f test_scenario=bookinfo.js \
  -f target_url=http://productpage.bookinfo.svc.cluster.local/productpage \
  -f total_vus=20 -f duration_seconds=60 -f runners=2
gh run list --repo "YOUR-OWNER/YOUR-REPO" --workflow load-test.yml --limit 5
gh run view RUN_ID --repo "YOUR-OWNER/YOUR-REPO" --web
```

Replace `RUN_ID` with your test's ID. Read **execution** and **cleanup** separately in the Summary; use its Grafana link when available to assess performance. Cleanup preserves the shared foundation.
