# Technical Challenge - GitHub Action Pipeline

[Back](../../README.md)

- [Technical Challenge - GitHub Action Pipeline](#technical-challenge---github-action-pipeline)
  - [GitHub Action Pipeline](#github-action-pipeline)
    - [Benefits](#benefits)
    - [Tool Selection](#tool-selection)
    - [Key Steps](#key-steps)
    - [Feature](#feature)
      - [Fully Automated](#fully-automated)
      - [Modular Workflow](#modular-workflow)
      - [Secret Management](#secret-management)
      - [Concurrency Control](#concurrency-control)
      - [AWS Access](#aws-access)
    - [What’s More](#whats-more)
      - [Team-Ready Improvements](#team-ready-improvements)
      - [Safe Teardown (Destroy Protection)](#safe-teardown-destroy-protection)

---

## GitHub Action Pipeline

### Benefits

- **Why pipeline is needed**
  - Automates the full workflow from **infrastructure provisioning** to **testing** and **cleanup**
  - Ensures **consistent, reproducible results** by running the same controlled steps every time
  - Eliminates manual errors and guarantees clean state between runs

---

### Tool Selection

- **Why GitHub Actions**
  - Native **integration** with `GitHub` repository (no separate CI server required)
  - Supports **OIDC with AWS** → secure, short-lived credentials (no hardcoded secrets)
  - Built-in `workflow_dispatch` → ideal for controlled, cost-aware infrastructure testing

- **Alternatives**
  - `Jenkins` → highly flexible but requires **server management** (operational overhead)
  - `GitLab CI` → strong alternative but **less seamless** `GitHub` integration

- **Why GitHub Actions fits this project**
  - Zero infrastructure to manage
  - Tight integration with code + secrets
  - Supports both manual and automated workflows

---

### Key Steps

- **Pipeline flow**
  - `Terraform` **provisions infrastructure** from clean state
  - `Smoke test` validates system health
  - k6 performs `load testing` with predefined config
  - `Terraform` **destroys** all resources to ensure no leftover state

- **Matrix strategy**
  - Used to **parallelize multiple architectures (e.g., 4 designs)**
  - Ensures fair comparison under identical conditions
  - Reduces total execution time

- **Smoke testing before load testing**
  - **Prevents** running load tests on **broken deployments**
  - Includes lightweight read/write checks (~1 min)

- **DNS validation (practical fix)**
  - Each design uses its own domain → `DNS propagation` delay
  - Added shell script to `curl` endpoint until expected status (e.g., 307)
  - Ensures service is reachable before testing

---

### Feature

#### Fully Automated

- **Triggers**
  - `workflow_dispatch` (manual) → controlled execution, avoids unnecessary cost
  - `push` (optional) → enables automation without human intervention

- **Why both**
  - Manual → **flexibility** for benchmarking and experiments
  - Push → **automation** for CI workflows

---

#### Modular Workflow

- **Design pattern**
  - Main **orchestration workflow** + **reusable workflows** for each stage

- **Benefits**
  - **Reusability** → same logic across environments/architectures
  - Consistency → identical steps reduce drift
  - Maintainability → update once, apply everywhere
  - Scalability → add new architecture via matrix entry

---

#### Secret Management

- **Handling secrets**
  - Stored in `GitHub Actions` **encrypted secrets**
  - Injected as environment variables (never hardcoded or logged)

- **Passing to Terraform**
  - Passed via environment variables (`TF_VAR_*`) or input variables

- **Best practice**
  - Avoid long-lived credentials
  - Use least-privilege IAM roles

---

#### Concurrency Control

- Prevent overlapping runs using:
  - `concurrency` + `cancel-in-progress: true`
- Ensures only one active run per environment
- **Avoids state conflicts** and resource contention

---

#### AWS Access

- **How access is handled**
  - Use **OIDC federation** instead of static credentials

- **Benefits**
  - No long-lived secrets
  - Short-lived, scoped credentials
  - Improved security posture

- **High-level setup**
  1. Configure OIDC provider in `AWS IAM`
  2. Create `IAM role` with `trust policy` for GitHub
  3. Grant least-privilege **permissions**
  4. GitHub Actions **assumes role** at runtime

---

### What’s More

#### Team-Ready Improvements

- **PR-based workflow**
  - Enforce pull requests for all Terraform changes (no direct push to main)
  - Attach `terraform plan` output to PR for visibility of infra changes

- **Pre-merge validation**
  - Add checks: `terraform fmt`, `terraform validate`
  - Integrate tools like `tflint` or `checkov` for security and policy validation

- **Module versioning**
  - Pin module sources to specific **git tags**
  - Prevent unintended changes across multiple architectures

- **Cost estimation**
  - Integrate tools like `Infracost` into pipeline
  - Show projected cost changes in plan output before apply

---

#### Safe Teardown (Destroy Protection)

- **Workflow control**
  - use `if: always()` so it runs regardless of whether earlier steps succeed or fail.
  - Add `wf-manual-destroy` workflow as safeguard to enable manual destroy.

- **State isolation**
  - Enables clear ownership, cost tracking, and safe cleanup targeting (e.g., `env=baseline`, `env=scale`, ...)
  - Use separate **Terraform state** per architecture
  - Ensures `destroy` only affects resources tracked in that specific state

---
