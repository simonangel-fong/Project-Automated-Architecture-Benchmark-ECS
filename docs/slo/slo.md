# Automated Architecture Benchmark (ECS) - Testing & SLO

[Back](../../README.md)

- [Automated Architecture Benchmark (ECS) - Testing \& SLO](#automated-architecture-benchmark-ecs---testing--slo)
  - [Testing \& SLO](#testing--slo)
    - [Load Testing Tool (k6)](#load-testing-tool-k6)
    - [Traffic Pattern Design](#traffic-pattern-design)
    - [Latency Metrics (p95 vs Average)](#latency-metrics-p95-vs-average)
    - [Failure Diagnosis](#failure-diagnosis)
    - [Metrics Correlation](#metrics-correlation)
    - [Observability Stack](#observability-stack)
    - [Test Validity](#test-validity)
    - [Monitoring Architecture](#monitoring-architecture)
    - [Business-Oriented](#business-oriented)
    - [Limitations of the Study](#limitations-of-the-study)

---

## Testing & SLO

### Load Testing Tool (k6)

- **Why k6**
  - Script-based (JavaScript) → version-controlled, easy to parameterize
  - CLI tool → integrates cleanly into CI/CD (GitHub Actions)
  - Strong support for **traffic modeling** (ramp, constant rate, stages)
  - Native integration with **Grafana**

- **Why not alternatives**
  - `JMeter` → XML-based, hard to maintain and review
  - `Locust` → similar but weaker Grafana integration

---

### Traffic Pattern Design

- **Strategy used**
  - **Ramped load profile with defined stages**
    - `STAGE_START` (1 min) → initial warm-up phase
    - `STAGE_RAMP` (20 min) → gradual increase to target RPS
    - `STAGE_PEAK` (5 min) → hold steady at peak load

- **Why**
  - Avoid cold-start bias:
    - ECS tasks not yet scaled
    - caches not warmed
    - connection pools not established
  - Allow **auto-scaling to react progressively** (real-world behavior)
  - Capture both:
    - system response during scaling
    - stable performance under sustained load

- **Insight**
  - Start phase → validates baseline readiness
  - Ramp phase → shows how quickly system adapts to load increase
  - Peak phase → measures **true steady-state capacity (RPS, p95 latency)**

- **Design benefit**
  - Makes results **reproducible and comparable across architectures**
  - Separates transient behavior from actual system performance

---

### Latency Metrics (p95 vs Average)

- **Why p95**
  - Captures **tail latency** (slowest 5%)
  - Reflects real user experience

- **Problem with average**
  - Masks slow requests
  - Can look acceptable while users suffer

- **In my project**
  - Baseline: high p95 (~3000ms) → poor user experience
  - Kafka: low p95 (~25ms) → consistent performance

---

### Failure Diagnosis

- **Observed issue (Baseline)**
  - 34.6% failure rate at 320 RPS

- **How I diagnosed**
  - ECS CPU saturated → application bottleneck
  - Errors: timeouts / 503 (not application errors)
  - DB CPU low (~19%) → DB not bottleneck

- **Conclusion**
  - Single ECS task cannot handle concurrent load
  - Confirmed by `scaling` → errors dropped to ~0%

---

### Metrics Correlation

- **How I correlated metrics**
  - k6 → sends RPS, latency, error rate to Grafana
  - CloudWatch → ECS, RDS metrics

- **Setup**
  - Unified dashboard with **same time axis**

- **Benefit**
  - Identify cause-effect relationships:
    - DB CPU ↑ → latency ↑
    - ECS scaling ↑ → latency ↓

---

### Observability Stack

- **Current setup**
  - Metrics:
    - CloudWatch (ECS, RDS)
    - k6 (RPS, latency, errors)
  - Visualization:
    - Grafana

- **Production improvements**
  - Distributed tracing (OpenTelemetry, X-Ray, Tempo)
  - Structured logging (JSON logs)
  - Alerting:
    - p95 latency
    - error rate
    - DB CPU
  - Synthetic monitoring (canary checks)

---

### Test Validity

- **How I ensured meaningful results**
  - Measure during **steady-state phase**
  - Wait until:
    - auto-scaling stabilizes
    - caches are warm
    - connections established

- **Additional validation**
  - Run tests multiple times
  - Check consistency across runs

- **Insight**
  - Early data = transient behavior
  - Only steady-state reflects real system capacity

---

### Monitoring Architecture

- **Metric sources**
  - CloudWatch → infrastructure metrics
  - k6 → load testing metrics

- **Integration**
  - Grafana Cloud connects to:
    - CloudWatch (via IAM role)
    - k6 (Prometheus remote write)

- **Result**
  - Single dashboard showing:
    - system behavior
    - load test metrics
    - real-time scaling response

---

### Business-Oriented

- **SLA → SLO → SLI Framework**

| Aspect      | SLI (Indicator)     | SLO (Objective)          | SLA (Agreement)         |
| ----------- | ------------------- | ------------------------ | ----------------------- |
| What is it? | Metric measurement  | Internal target          | External contract       |
| Purpose     | Measure performance | Define reliability       | Define liability        |
| Audience    | Engineering         | Product & Engineering    | Customer / Legal        |
| Consequence | Alerts / Debugging  | Error budget consumption | Financial / contractual |

- **Metrics**
  - **Availability (Reliability)**
    - SLI: **Error rate**
    - SLO: **< 0.1% failure rate**
    - Why it matters:
      - Ensures successful request completion
      - Directly impacts user trust and revenue

  - **Latency (User Experience)**
    - SLI: **p95 latency**
    - SLO: **< 200ms p95**
    - Why it matters:
      - Captures real user experience (tail latency)
      - High latency leads to user drop-off

  - **Throughput (Capacity)**
    - SLI: **Requests per second (RPS)**
    - Target: **≥ 1,000 RPS sustained**
    - Why it matters:
      - Validates system capacity under peak load
      - Ensures the system scales without degradation

---

### Limitations of the Study

- **Synthetic traffic model**
  - Uses controlled k6 patterns (fixed RPS, limited endpoints)
  - Real traffic is more diverse and bursty
  - Cache hit rate is likely **overestimated**

- **Simplified application**
  - FastAPI service is lightweight and lacks real-world complexity
  - Does not include:
    - complex business logic
    - external dependencies
    - multi-step workflows
  - Results may not reflect production variability

- **Isolated environment**
  - No noisy neighbors or shared resource contention
  - No network variability (multi-region, latency differences)
  - No operational events (deployments, failures, maintenance)
