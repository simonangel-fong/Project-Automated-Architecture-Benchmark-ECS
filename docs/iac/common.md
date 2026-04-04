## Terraform (IaC) — Advanced Interview Q&A

### Drift Detection

- **What is drift?**
  - When actual infrastructure differs from Terraform state

- **How I handle it**
  - Use `terraform plan` to detect unexpected changes
  - Pipeline surfaces drift before apply
  - Since my infra is ephemeral, I can safely re-apply or destroy and recreate

---

### Idempotency

- **What does idempotent mean in Terraform?**
  - Running the same configuration multiple times produces the same result

- **In my project**
  - Ensures each benchmark run is consistent
  - No changes are applied if infrastructure already matches desired state

---

### Dependency Management

- **How Terraform handles dependencies**
  - Implicit dependencies via resource references
  - Example: ECS service depends on ALB, subnets, security groups

- **When needed**
  - Use `depends_on` for explicit control

- **In my project**
  - Ensures correct provisioning order across multi-service architectures

---

### State Security

- **Why state needs protection**
  - State file may contain sensitive data (e.g., resource attributes, credentials)

- **How I secure it**
  - Store state in **S3 backend** with encryption enabled
  - Restrict access via IAM roles (least privilege)
  - Use OIDC from GitHub Actions → no long-lived credentials

---

### State Sensitivity

- **Why Terraform state is sensitive**
  - Contains full infrastructure mapping
  - May expose secrets or internal architecture details

- **Best practices**
  - Never commit state file to Git
  - Use remote backend with restricted access
  - Limit who can read/write state

---

### Rollback Strategy (Optional)

- **Does Terraform support rollback?**
  - No native rollback (not transactional)

- **How I handle failures**
  - Re-run `terraform apply` to converge state
  - Use `terraform destroy` + re-provision for clean recovery
  - Pipeline ensures cleanup always runs (`if: always()`)

- **In my project**
  - Since infra is temporary, recovery is simple and low-risk
