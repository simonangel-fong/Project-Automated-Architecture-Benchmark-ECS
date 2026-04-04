## CI/CD — Advanced Interview Q&A

### Pipeline Failure Handling

- **How do you handle failures in pipeline?**
  - Use `fail-fast` for critical steps (e.g., deployment failure stops pipeline)
  - Use `if: always()` for cleanup (e.g., Terraform destroy)
  - Separate critical stages to isolate failure impact

- **In my project**
  - Cleanup is guaranteed even if load test or deploy fails
  - Prevents resource leakage and cost issues

---

### Artifact Management

- **How do you manage artifacts between steps?**
  - Use GitHub Actions artifacts to store outputs (e.g., Terraform plan, logs)

- **In my project**
  - Cache/store Terraform plan for audit and debugging
  - Helps compare expected vs actual changes

---

### Environment Isolation

- **How do you isolate environments in CI/CD?**
  - Use separate configs, variables, and state per environment

- **In my project**
  - Each architecture has its own Terraform state and pipeline context
  - Prevents cross-environment interference

---

### Pipeline Performance Optimization

- **How do you optimize pipeline performance?**
  - Use matrix strategy for parallel execution
  - Cache dependencies and intermediate results

- **In my project**
  - Parallelize testing across 4 architectures
  - Reduce total benchmark time

---

### Observability and Debugging

- **How do you debug pipeline failures?**
  - Use structured logs and step outputs
  - Store artifacts for inspection

- **In my project**
  - Use logs + Terraform plan output for debugging infra issues
  - Helps identify deployment vs performance issues

---

### CI/CD Security

- **How do you secure the pipeline?**
  - Use encrypted secrets
  - Avoid hardcoded credentials
  - Use OIDC for short-lived credentials

- **Best practices**
  - Apply least-privilege IAM roles
  - Limit workflow permissions (e.g., restrict write access)

---

### Approval and Governance

- **When do you require manual approval?**
  - For production or destructive operations

- **In my project**
  - Benchmark pipeline is automated
  - For team setup, would add approval before `terraform destroy` or apply
