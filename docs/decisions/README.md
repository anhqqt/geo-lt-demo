# Architecture decisions

- [Reading order](#reading-order)
- [Updating decisions](#updating-decisions)

These records explain the alternatives, selected design and accepted trade-offs for the load-testing demo. Read them in the order below, starting with what a test owns and ending with how the platform and application are packaged.

All eight decisions and the final demo are accepted. Their evidence sections distinguish demonstrated behavior from accepted limits. Publication, independent Git-clone checks, hosted timer verification and four videos are complete; [validation](../validation.md#acceptance-coverage) owns the final evidence scope.

## Reading order

- [Define the test and choose the tools](#define-the-test-and-choose-the-tools)
- [Organize and deploy the foundation](#organize-and-deploy-the-foundation)

The numbering follows this reading order. Links between records connect related decisions and later design details.

### Define the test and choose the tools

| ADR | Question it answers |
|---|---|
| [0001: Existing Dev services and real dependencies](0001-existing-dev-services-and-dependencies.md) | What is prepared before a test, and which resources belong to each run? |
| [0002: EKS execution platform](0002-eks-execution-platform.md) | Where do the application, monitoring and generators run, and what do they share? |
| [0003: k6 Operator](0003-k6-operator-load-generator.md) | How is load distributed, measured and assessed across runners? |
| [0004: GitHub Actions](0004-github-actions-self-service-workflow.md) | How does a developer request a test, access results and trigger cleanup within the allowed permissions? |

### Organize and deploy the foundation

| ADR | Question it answers |
|---|---|
| [0005: Terragrunt orchestration](0005-terragrunt-iac-orchestration.md) | How are infrastructure layers, dependencies, separate states and shared defaults organized? |
| [0006: AWS naming and state layout](0006-aws-resource-naming-and-state-layout.md) | How do resource names and state addresses identify each environment, region and unit? |
| [0007: Bootstrap addon modules](0007-bootstrap-addon-modules.md) | How are controllers, monitoring, permissions and endpoint DNS owned and removed? |
| [0008: Bookinfo service charts](0008-bookinfo-service-charts.md) | How do four service releases share templates and one state while keeping their own defaults? |

The [architecture](../architecture.md) shows how these choices fit together. The [setup guide](../setup.md) covers deployment steps and their current verification limits.

## Updating decisions

Add a new record as `NNNN-descriptive-name.md` using the next available number. Explain its context, alternatives, decision and consequences; keep the status explicit.

Use `Proposed` while a choice is under review and `Accepted` after human approval. If a later decision replaces it, retain the existing record, mark it `Superseded` and link its replacement. A rejected proposal can remain marked `Rejected` when its reasoning is useful.

Update this index and affected references when adding or superseding a decision. Implementation progress and test evidence belong in each record's evidence section and the relevant operating documents.
