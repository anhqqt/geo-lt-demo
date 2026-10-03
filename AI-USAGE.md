# AI usage

I used OpenAI Codex in the desktop app for research, design discussions, Terraform/Helm implementation, tests, runtime checks and documentation. I set the scope, chose the design and remained responsible for accepting the results.

I recorded the four demo videos myself. Codex helped prepare the scenarios, check the files and connect them to the run evidence.

The submission includes the implementation and selected evidence. Detailed development plans and private validation artifacts remain outside it.

## How I directed the work

I used a spec-driven workflow, with AI agents assigned to bounded tasks:

1. **Problem and requirements.** Start with the assignment, my assumptions and candidate approaches. Separate required outcomes from optional ideas in the [specification](docs/specification.md).
2. **Technical design.** Discuss alternatives and trade-offs, then record the chosen design in [architecture](docs/architecture.md). [Architecture Decision Records (ADRs)](docs/decisions/README.md) preserve the reasons and accepted limits for later slices.
3. **Small plans.** Give each slice a clear outcome, files it may change and acceptance criteria. Plan validation before implementation, including expected results and relevant failure, recovery and post-deployment checks.
4. **Implementation and AI review.** Implement the agreed scope, then run focused checks. Delegate independent work with separate file ownership and use another agent to review consequential changes.
5. **Human acceptance.** Each completed slice requires my review of the changes, validation results and remaining limitations. I decide whether to accept it, request changes or leave work pending.

Project instructions and role files define agent responsibilities and constraints. They guide delegation; they do not run an automatic pipeline or replace my decisions.

## Representative prompts and decisions

These are illustrative prompts based on recorded decisions and the project workflow. They are not verbatim chat excerpts.

### 1. Brainstorming: choosing k6 for distributed load

> `$brainstorming`
>
> Compare k6 Operator, Locust and JMeter for distributed HTTP load on EKS. We need bounded total VUs, Prometheus/Grafana results and cleanup that preserves shared services. Explain the integration effort, permissions and limits of each option, especially how results from multiple runners should be assessed.

I chose k6 Operator for its JavaScript workloads and controls for distributed runners on EKS. The trade-off is another controller to maintain and thresholds evaluated per runner. The demo leaves whole-run performance assessment to the developer.

YAGNI and KISS shaped the scope: reuse Dev services and real dependencies, with temporary k6 resources per run. The published GitHub Actions runtime has real Bookinfo load and cleanup evidence; the validation record preserves native threshold failures and other limitations.

### 2. Writing plans: organize Terragrunt by layer

Before discussing IaC with AI, I considered plain Terraform, Terragrunt with Terraform, and CDKTF. My uncertainty was whether Terragrunt's benefits justified the extra work. I accepted that cost for shared configuration and dependencies between units, as explained in the [writeup](WRITEUP.md).

> `$writing-plans`
>
> Turn the accepted Terragrunt design into a plan for one Dev account:
>
> - Global: account-wide identity and DNS.
> - Core: regional VPC and ACM.
> - Platform: regional cluster, bootstrap, then service pillars.
>
> Use separate units and states, with shared provider, backend and tag settings. Define dependencies, allowed file changes and expected outcomes for each step. Separate local checks from AWS validation and include recovery checks where needed.

DRY appears in the shared configuration. I applied SOLID's single-responsibility principle through focused module responsibilities, including separate cluster, platform bootstrap and Bookinfo ownership.

### 3. Executing plans: deliver one infrastructure layer at a time

> `$executing-plans`
>
> Implement only the regional Core slice from the approved plan. Reuse shared configuration and consume Global outputs where needed. Run focused checks after implementation, then show the Terraform plan for my review before deployment. Report validation results and gaps before moving to Platform.

The foundation has separate Global, Core, cluster and bootstrap slice records. They distinguish local validation from authorized AWS deployment and runtime checks.

### 4. Requesting code review: check the layer boundaries

> `$requesting-code-review`
>
> Review the Terragrunt slice against the accepted design. Check unit and state ownership, dependency outputs and shared configuration. Flag changes outside the approved scope and unexpected resource replacements. Check the validation evidence and remaining recovery checks. Separate blocking findings from optional improvements.

I must review the changes, check results and unresolved findings before accepting the slice. An AI review can identify issues; the final decision remains mine.

## Tools and selected skills

Skills supplied instructions for specific tasks within the project rules:

- **Superpowers:** `brainstorming` to clarify choices; `writing-plans` to split work into testable slices; `executing-plans` to follow the accepted scope; `requesting-code-review` for an independent AI review.
- **diagram-design:** create diagrams with clear labels and consistent visual structure.

The project adapts these skills: implement first, then run focused checks and demonstrate the working behavior. Upstream skill defaults do not override that workflow.

## Validation and human review

Plans define expected outcomes; validation records state what actually happened. My acceptance requires human review. Passing tests or an AI review alone does not complete that step.

- **Local checks:** Terraform validation, plans with mocked providers and Helm rendering checked configuration and expected changes. These checks do not establish AWS behavior.
- **AWS checks:** after I deployed the full Bookinfo pillar, Codex checked service readiness, real dependency calls, internal/public routes, shared ALB health and DNS/TLS. A temporary connectivity probe was removed and its absence verified.
- **Human confirmation:** I separately confirmed Bookinfo exposure removal and restoration. The record identifies this as my confirmation, without claiming Codex reproduced that exercise.
- **Workflow checks:** Codex ran authorized, bounded Dev scenarios covering input rejection, native-threshold/HTTP failures, distributed metrics and UID-scoped cleanup. GitHub OIDC and EKS token renewal also had separate checks without load.
- **Viewer checks:** the approved Grafana Viewer account was checked against live and retained results from a successful public run. The upstream dashboard's display limits remain documented.

Publication, independent Git-clone checks, hosted timer verification and the four recordings have evidence. I accepted the submission package and its private-repository access handoff. Codex did not independently test playback in the recipient's account.

The accepted demo is the final scope.[Validation](docs/validation.md) distinguishes each run's criteria, excluded checks and later resource changes from historical evidence.
