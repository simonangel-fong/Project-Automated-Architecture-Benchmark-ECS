# Automated Architecture Benchmark (ECS) - Terraform (IaC)

[Back](../../README.md)

- [Automated Architecture Benchmark (ECS) - Terraform (IaC)](#automated-architecture-benchmark-ecs---terraform-iac)
  - [Terraform (IaC)](#terraform-iac)
    - [Benefits](#benefits)
    - [State Management](#state-management)
    - [Terraform Workflow (init, fmt, validate, plan, apply, destroy)](#terraform-workflow-init-fmt-validate-plan-apply-destroy)
    - [Segregation with Pipeline](#segregation-with-pipeline)
    - [Secret Management](#secret-management)
    - [Modular vs Resource Design](#modular-vs-resource-design)

---

## Terraform (IaC)

### Benefits

- **Why Terraform**
  - Infrastructure defined as code → version-controlled, repeatable, and auditable
  - Enables **consistent provisioning** across environments
  - Supports automation in CI/CD pipelines
  - Cloud-agnostic with strong ecosystem and community support

---

### State Management

- **How Terraform manages state**
  - Uses a **state file**(`terraform.tfstate`) to track resource mappings
  - Uses **state locking** to prevent concurrent modifications

- **Common approaches**
  - Local state → `terraform init` simple but not suitable for team or CI/CD
  - Remote state → `terraform init -backend-config=` typically S3

- **In my project**
  - Use **remote S3 backend** for centralized and consistent state

- **State isolation for 4 designs**
  - Each architecture has its **own state file**
  - Isolated using backend key (e.g., `env=baseline`, `env=scale`, etc.)
  - Prevents cross-impact between different infrastructure designs

---

### Terraform Workflow (init, fmt, validate, plan, apply, destroy)

- **Steps**
  - `init` → initialize backend and providers
  - `fmt` → enforce code formatting
  - `validate` → check syntax and configuration
  - `plan` → preview infrastructure changes
  - `apply` → execute changes
  - `destroy` → clean up all resources

- **Execution flow**
  - Each step runs **only if the previous one succeeds**
  - Ensures safe and predictable deployment

- **Pipeline enhancement**
  - Cache or store **plan output in GitHub Actions**
  - Enables audit and debugging of infrastructure changes

---

### Segregation with Pipeline

- **Why not use workspaces**
  - Workspaces are suitable for **same infrastructure** with **different variables** (e.g., dev/staging/prod)
  - My designs have **different architectures and services** → not suitable

- **How I manage Terraform**
  - Separate directories under `aws/` (e.g., baseline, kafka, redis, etc.)
  - Each has its own variables and tagging strategy
  - Ensures clear separation and avoids conditional complexity

---

### Secret Management

- **Common approach**
  - Use `.tfvars` files (not committed for sensitive data)

- **Pipeline integration**
  - Store secrets in `GitHub Actions` **encrypted secrets**
  - Pass values using environment variables (`TF_VAR_*`)

- **Best practice**
  - Avoid hardcoding sensitive values
  - Use least-privilege access

---

### Modular vs Resource Design

- **Benefits of modular design**
  - **Reusability** → shared components (e.g., VPC, ECS, RDS)
  - **Consistency** → same baseline across architectures
  - **Maintainability** → update once, apply everywhere

- **Practical decision in my project**
  - Skip using modular: to significantly reduce the cost (~25%) (e.g., VPC logging via CloudWatch)
  - Decisions are made balancing **reusability vs cost and simplicity**
