# Automated Architecture Benchmark (ECS)

**One Pipeline. Four Designs. Real Metrics.**

Welcome to visit my project website 👉 [website](https://ecs-benchmark.arguswatcher.net/)

![AWS](https://img.shields.io/badge/AWS-FF9900?style=for-the-badge&logo=amazonwebservices&logoColor=white&style=plastic) ![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white&style=plastic) ![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white&style=plastic) ![Grafana](https://img.shields.io/badge/grafana-%23F46800.svg?style=for-the-badge&logo=grafana&logoColor=white&style=plastic) ![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF?style=for-the-badge&logo=githubactions&logoColor=white&style=plastic) ![Redis](https://img.shields.io/badge/redis-%23DD0031.svg?style=for-the-badge&logo=redis&logoColor=white&style=plastic) ![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi&style=plastic)

- [Automated Architecture Benchmark (ECS)](#automated-architecture-benchmark-ecs)
  - [Motivation](#motivation)
  - [Results](#results)
  - [Four Designs](#four-designs)
  - [One Pipeline](#one-pipeline)
  - [Tech Stack](#tech-stack)

---

## Motivation

Architecture advice is often theoretical — "add caching," "use a message queue" — without data to back it up. This project answers a practical question:

**How much does each architectural decision actually move the needle under real load?**

Four designs. One automated pipeline. Identical traffic conditions. Real numbers.

---

## Results

Four architectures were tested in progression — Baseline, Auto-Scaling, Redis Caching, and Kafka — each addressing a limitation of the previous.

**Baseline → Kafka:**

- **+213% Throughput Improvement** — 320 → 1,000 RPS
- **-99% Latency Reduction** — 3,000ms → 25ms (p95)
- **~0% Request Failures** — nearly eliminated at 1,000 RPS
- **-67% Database CPU Reduction** — 48.6% → 15.8%

---

**Technical Comparison** - [Load Testing Snapshot](https://simonangelfong.grafana.net/dashboard/snapshot/vm8GHz4ne3ej2IijhAXtitw74oAXRSKr?orgId=1&from=2026-02-16T05:45:00.000Z&to=2026-02-16T06:20:00.000Z&timezone=browser&refresh=5s)

| Architecture | Peak RPS | HTTP Failures | P95 Latency | ECS Tasks (Peak) | DB CPU |
| ------------ | -------- | ------------- | ----------- | ---------------- | ------ |
| Baseline     | 320      | 34.6%         | 3,000ms     | 1                | 19.2%  |
| Scale        | 1,000    | ~0%           | 70ms        | 18               | 48.6%  |
| Redis        | 1,000    | ~0%           | 75ms        | 16               | 34.9%  |
| Kafka        | 1,000    | ~0%           | 25ms        | 10               | 15.8%  |

![dashboard](./docs/resource/grafana_dashboard.gif)

**Business Impact**

| Architecture | Business Continuity | DB Overload Risk | Operational Cost | Complexity |
| ------------ | ------------------- | ---------------- | ---------------- | ---------- |
| Baseline     | ❌ Low              | 🔴 High          | 🟢 Low           | 🟢 Low     |
| Scale        | 🟢 High             | 🟠 Medium–High   | 🟠 Medium        | 🟠 Medium  |
| Redis        | 🟢 High             | 🟡 Medium        | 🟠 Medium        | 🟠 Medium  |
| Kafka        | 🟢 Very High        | 🟢 Low           | 🔴 High          | 🔴 High    |

- Further analysis: [Metric Analysis](./docs/metric/metric.md) | [System Design](./docs/system_design/system_design.md)

---

## Four Designs

Each architecture addresses a limitation of the previous, tested under identical conditions.

![baseline](./app/html/img/diagram/baseline.gif)

![scale](./app/html/img/diagram/scale.gif)

![redis](./app/html/img/diagram/redis.gif)

![kafka](./app/html/img/diagram/kafka.gif)

- Technical Details: [Terraform (IaC)](./docs/iac/iac.md) | [GitHub Actions Pipeline](./docs/pipeline/pipeline.md) | [SLO Metrics](./docs/slo/slo.md)

---

## One Pipeline

One automated workflow runs across all four designs — ensuring every benchmark is provisioned, tested, and torn down under identical conditions.

| Step | Action                   | Tool             |
| ---- | ------------------------ | ---------------- |
| 1    | Provision infrastructure | Terraform · Helm |
| 2    | Validate deployment      | Smoke test       |
| 3    | Load testing             | k6               |
| 4    | Tear down infrastructure | Terraform        |

![pipeline](./docs/resource/github_action.gif)

- Technical challenges
  - [Pipeline Design](./docs/pipeline/pipeline.md)

[Pipeline design decisions — why GitHub Actions, why k6, and how state is managed across steps](link)

---

## Tech Stack

| Role               | Tools                                                |
| ------------------ | ---------------------------------------------------- |
| **Infrastructure** | AWS ECS · RDS · ElastiCache · MSK · Terraform · Helm |
| **CI/CD**          | GitHub Actions · Docker                              |
| **Load Testing**   | k6                                                   |
| **Observability**  | Grafana · CloudWatch                                 |
| **Backend**        | Python · FastAPI                                     |

---
