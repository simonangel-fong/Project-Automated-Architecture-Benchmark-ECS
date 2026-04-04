# Automated Architecture Benchmark (ECS) - Architecture & System Design

[Back](../../README.md)

- [Automated Architecture Benchmark (ECS) - Architecture \& System Design](#automated-architecture-benchmark-ecs---architecture--system-design)
  - [Architecture Comparison](#architecture-comparison)
    - [`Baseline`](#baseline)
    - [`Scale`](#scale)
    - [`Redis`](#redis)
    - [`Kafka`](#kafka)
    - [Redis vs Scale](#redis-vs-scale)
    - [Architecture Progression](#architecture-progression)
    - [Multi-region Deployment](#multi-region-deployment)
    - [Traffic Spikes (10×)](#traffic-spikes-10)
  - [AWS ECS](#aws-ecs)
    - [AWS ECS Fargate](#aws-ecs-fargate)
    - [ECS Auto-scaling Policy](#ecs-auto-scaling-policy)
    - [ECS Fargate vs EC2 Launch Types](#ecs-fargate-vs-ec2-launch-types)
    - [Health Checks](#health-checks)
    - [ECS Task Definition](#ecs-task-definition)
    - [ECS Logging](#ecs-logging)
    - [ECS Fargate Sizing](#ecs-fargate-sizing)
    - [ECS Task Failure Handling](#ecs-task-failure-handling)
  - [AWS ECS](#aws-ecs-1)
    - [ECS Fargate](#ecs-fargate)
    - [ECS Auto-scaling Policy](#ecs-auto-scaling-policy-1)
    - [ECS Fargate vs EC2 Launch Types](#ecs-fargate-vs-ec2-launch-types-1)
    - [Health Checks](#health-checks-1)
    - [ECS Task Definition](#ecs-task-definition-1)
    - [ECS Logging](#ecs-logging-1)
    - [ECS Fargate Sizing](#ecs-fargate-sizing-1)
    - [ECS Task Failure Handling](#ecs-task-failure-handling-1)
  - [Caching \& Database Design](#caching--database-design)
    - [Redis Caching Strategy](#redis-caching-strategy)
    - [Cache Invalidation](#cache-invalidation)
    - [Cache Hit Rate](#cache-hit-rate)
    - [TTL Strategy](#ttl-strategy)
    - [Cache Stampede Prevention](#cache-stampede-prevention)
    - [RDS Design](#rds-design)
    - [Database Connection Management](#database-connection-management)
    - [Redis Deployment Choice](#redis-deployment-choice)
    - [Redis Data Structure](#redis-data-structure)
  - [Kafka / MSK Design](#kafka--msk-design)
    - [Workload Decoupling](#workload-decoupling)
    - [Data Flow \& Consistency](#data-flow--consistency)
    - [Consumer Lag](#consumer-lag)
    - [Partition \& Replication Design](#partition--replication-design)
    - [Message Failure Handling](#message-failure-handling)
    - [Delivery Guarantee](#delivery-guarantee)
    - [Resilience Improvement](#resilience-improvement)
    - [Scaling Strategy](#scaling-strategy)
    - [Trade-off Summary](#trade-off-summary)

---

## Architecture Comparison

### `Baseline`

- **Metrics**
  - Peak RPS: **~320**
  - Error rate: **34.6%**
  - High **latency** and **failure under** load

- **Trade-offs**
  - pros:
    - **Simple and easy to implement**
    - Minimal infrastructure and cost
    - Good for understanding system limits
  - cons:
    - Single ECS task becomes **bottleneck**
    - No scaling → cannot handle concurrent requests

- **Common use cases**
  - Early-stage development
  - Proof of Concept (POC)
  - Low-traffic internal tools

---

### `Scale`

- **Metrics**
  - Throughput: **~1000 RPS**
  - Error rate: **~0%**
  - ECS tasks: **1 → 18**
  - DB CPU: **up to 48.6%**

- **Trade-offs**
  - Pros:
    - Solves compute bottleneck via **horizontal scaling**
  - Cons:
    - Introduces **new bottleneck at database layer**
    - Limited scalability beyond DB capacity
    - High DB contention (many tasks hitting DB)

- **Common use cases**
  - Stateless web services
  - **Moderate scale** applications
  - Systems where DB is not yet bottleneck

---

### `Redis`

- **Metrics**
  - DB CPU reduced: **48.6% → 34.9%**
  - Slight reduction in ECS tasks
  - Improved read performance

- **Trade-offs**
  - Pros:
    - Caching reduces **read load on database**
    - Improves response time for hot data
  - Cons:
    - Limited impact on **write-heavy workloads**
    - Cache invalidation complexity
    - Additional infrastructure (Redis cluster)

- **Common use cases**
  - Read-heavy applications
  - Session storage
  - Frequently accessed data caching

---

### `Kafka`

- **Metrics**
  - DB CPU: **34.9% → 15.8%** (major reduction)
  - ECS tasks: **16/18 → 10** (higher efficiency)
  - Lower latency due to **asynchronous processing**

- **Trade-offs**
  - Pros:
    - Decouples write operations via **message queue**
    - API returns immediately → no DB wait
    - Reduces contention and improves throughput per task
  - Cons:
    - **Startup time** → ~30 min to bootstrap (MSK cluster)
    - **Higher cost** → infrastructure + brokers
    - **Operational complexity**
      - topic/partition management
      - consumer groups & offsets
      - backup / recovery / DLQ

- **Common use cases**
  - High-throughput event streaming
  - Asynchronous processing systems
  - Microservice decoupling
  - Log/event pipelines

---

### Redis vs Scale

- **Metrics difference**
  - DB CPU: **48.6% → 34.9%** (significant drop)
  - ECS tasks: **18 → 16** (minor reduction)

- **What makes the difference**
  - Redis **offloads read operations** via caching
  - Reduces direct pressure on database

- **Why improvement is not significant**
  - Workload is **read:write = 1:1 (write-heavy)**
  - Writes and cache-miss queries still hit DB synchronously
  - ECS tasks are still **waiting on DB**, not CPU-bound

---

### Architecture Progression

- **Why 4 designs**
  - Each design solves a bottleneck observed in the previous one

- **Progression**
  - Baseline → single instance → fails under load
  - Scale → fixes compute bottleneck via auto-scaling
  - Redis → reduces DB read pressure via caching
  - Kafka → decouples writes → removes DB bottleneck

---

### Multi-region Deployment

- **How to extend to multi-region**
  - Database → use Aurora Global Database (primary + read replicas)
  - Cache → separate Redis per region (no shared state)
  - Kafka → use MirrorMaker for cross-region replication
  - Routing → Route53 latency/geolocation routing
  - Pipeline → parameterize Terraform by region + separate state

---

### Traffic Spikes (10×)

- **Bottleneck progression (Kafka example)**
  1. ECS → scaling delay (60–90s warmup) → latency spike
  2. Kafka → producer throughput / broker saturation
  3. RDS → write throughput becomes final bottleneck

- **Mitigation**
  - Pre-scale ECS (predictive scaling)
  - Scale Kafka brokers + partitions
  - Optimize DB (Aurora, connection pooling, sharding)

---

## AWS ECS

### AWS ECS Fargate

- **ECS vs EKS vs Lambda**
  - ECS → simpler container orchestration, less operational overhead
  - EKS → adds Kubernetes complexity (control plane, networking, node management)
  - Lambda → introduces cold starts and execution constraints

- **Why ECS (Fargate)**
  - Focus on **architecture performance**, not infrastructure complexity
  - No need to manage EC2 instances
  - Consistent runtime across all designs → fair comparison

---

### ECS Auto-scaling Policy

- **Common policies**
  - Target tracking → maintain metric (e.g., CPU) at target value
  - Step scaling → scale in/out based on thresholds
  - Scheduled scaling → pre-scale for known traffic patterns

- **In my project**
  - Scale on **CPUUtilization (~25%)**
  - Use **Step Scaling** to adjust task count
  - CPU chosen because workload is **compute-bound**

---

### ECS Fargate vs EC2 Launch Types

- **Difference**
  - Fargate → serverless, AWS manages compute
  - EC2 → user manages instances (capacity, patching, scaling)

- **Why Fargate**
  - Removes infrastructure management overhead
  - Avoids capacity planning issues
  - Ideal for benchmarking (focus on architecture only)

- **Trade-off**
  - Higher cost
  - Less control (no custom AMI, limited tuning)

---

### Health Checks

- **ALB level**
  - Target group checks `/api/health`
  - If success → task receives traffic
  - If fail → traffic is stopped

- **ECS level**
  - Container health check (e.g., curl `/api/health`)
  - If fail → ECS restarts container

- **Behavior**
  - New tasks must pass health check before receiving traffic
  - During scale-in → ALB drains connections before stopping tasks

---

### ECS Task Definition

- **Format**
  - Defined in Terraform (not raw JSON/YAML)

- **In my project**
  - Use `templatefile (tftpl)` with variables
  - Dynamically inject:
    - image (ECR)
    - secrets (Secrets Manager)
    - environment variables

---

### ECS Logging

- **Configuration**
  - Use `awslogs` log driver

- **CloudWatch Logs**
  - Separate log group per architecture
  - Centralized logging for debugging

- **Usage**
  - Correlate logs with metrics (Grafana / CloudWatch)

---

### ECS Fargate Sizing

- **Fargate constraints**
  - Fixed CPU/memory combinations

- **In my project**
  - Tested locally to identify bottleneck → CPU-bound
  - Selected **1 vCPU / 2GB memory**
  - Same size across all architectures → fair comparison

---

### ECS Task Failure Handling

- **How ECS handles failure**
  - Service scheduler maintains desired task count
  - If task fails:
    - Mark unhealthy
    - Deregister from ALB (connection draining)
    - Launch replacement task

- **Behavior under load**
  - Remaining tasks absorb traffic temporarily
  - If no headroom → risk of cascading failures

- **In my project**
  - Scale architecture has enough redundancy to absorb failures

---

## AWS ECS

### ECS Fargate

- **ECS vs EKS vs Lambda**
  - `ECS` → simpler container orchestration, less operational overhead
  - `EKS` → adds Kubernetes complexity (control plane, networking, node management)
  - `Lambda` → introduces cold starts and execution constraints(max 15m)

- **Why ECS (Fargate)**
  - Focus on **architecture performance**, not infrastructure complexity
  - No need to manage EC2 instances
  - Consistent runtime across all designs → fair comparison

---

### ECS Auto-scaling Policy

- **Common policies**
  - `Target tracking` → maintain metric (e.g., CPU) at target value
  - `Step scaling` → scale in/out based on thresholds
  - `Scheduled scaling` → pre-scale for known traffic patterns

- **In my project**
  - Scale on **CPUUtilization (~25%)**
  - Use **Step Scaling** to adjust task count
  - CPU chosen because the cpu is the contraint

---

### ECS Fargate vs EC2 Launch Types

- **Difference**
  - `Fargate` → serverless, AWS manages compute
  - `EC2` → user manages instances (capacity, patching, scaling)

- **Why Fargate**
  - Removes infrastructure **management overhead**
  - Avoids capacity planning issues
  - Ideal for benchmarking (focus on architecture only)

- **Trade-off**
  - Higher cost
  - Less control (no custom AMI, limited tuning)

---

### Health Checks

- **ALB level**
  - `Target group` checks `/api/health`
  - If success → task receives traffic
  - If fail → traffic is **stopped routing**

- **ECS level**
  - Container health check (e.g., curl `/api/health`)
  - If fail → ECS **restarts** container

- **Behavior**
  - New tasks **must pass** health check before **receiving** traffic
  - During scale-in → ALB **drains connections** before stopping tasks

---

### ECS Task Definition

- **Format**
  - Defined in Terraform (not raw JSON/YAML)

- **In my project**
  - Use `templatefile (tftpl)` with variables
  - Dynamically inject:
    - image (ECR)
    - secrets (Secrets Manager)
    - environment variables

---

### ECS Logging

- **Configuration**
  - Use `awslogs` log driver

- **CloudWatch Logs**
  - Separate log group per architecture
  - Centralized logging for debugging

- **Usage**
  - Correlate logs with metrics (Grafana / CloudWatch)

---

### ECS Fargate Sizing

- **Fargate constraints**
  - Fixed CPU/memory combinations

- **In my project**
  - Tested locally to identify bottleneck → CPU-bound
  - Selected **1 vCPU / 2GB memory**
  - Same size across all architectures → fair comparison

---

### ECS Task Failure Handling

- **How ECS handles failure**
  - Service scheduler maintains desired task count
  - If task fails:
    - Mark unhealthy
    - Deregister from ALB (connection draining)
    - Launch replacement task

- **Behavior under load**
  - Remaining tasks absorb traffic temporarily
  - If no headroom → risk of cascading failures

- **In my project**
  - Scale architecture has enough redundancy to absorb failures

---

## Caching & Database Design

### Redis Caching Strategy

- **What I cached**
  - Read-heavy, frequently accessed, relatively stable data
  - Example: entity lookups, aggregated reads
  - Avoid user-specific or transactional data

- **Caching pattern (Redis design)**
  - Use **cache-aside pattern**
    - Read path:
      - Check Redis → hit → return
      - Miss → query DB → store in Redis (with TTL) → return
  - Simple and effective for reducing DB read pressure

- **Data consistency (Kafka design)**
  - Use **outbox pattern** to keep Redis and PostgreSQL in sync
    - Write flow:
      - Application writes to DB + outbox table
      - Kafka publishes change events
      - Consumer updates/invalidate Redis cache

---

### Cache Invalidation

- **Strategy used**
  - **TTL-based expiration**
    - Benchmark: 30–60 seconds
    - Telemetry use case: **up to 1 hour TTL**
  - No active invalidation on writes

- **Why**
  - Telemetry data is **append-only and time-based**, not frequently updated
  - Slight staleness is acceptable → fits **eventual consistency**
  - Keeps system **simple and decoupled** from write logic

- **Trade-off**
  - Short window of stale data
  - Longer TTL improves cache efficiency but reduces freshness

- **Production alternative**
  - Active invalidation (delete/update cache on write)
  - Or event-driven invalidation (e.g., Kafka) for better consistency
  - Required for **real-time or strongly consistent workloads**

---

### Cache Hit Rate

- **How measured**
  - Redis metrics: `keyspace_hits / (hits + misses)`

- **Observed impact**
  - DB CPU reduced: **48.6% → 34.9% (~28%)**

- **Insight**
  - Benchmark hit rate is **optimistic**
    - Limited query diversity (k6 repeated patterns)
  - Real-world traffic → lower hit rate → smaller impact

---

### TTL Strategy

- **In my project**
  - Benchmark: **30–60 seconds**
  - Telemetry use case: **up to 1 hour TTL**

- **Why**
  - Benchmark:
    - Avoid cold-start bias (cache always warm)
    - Avoid excessive churn (too short TTL)
    - Measure steady-state performance
  - Telemetry:
    - Data is **append-only and time-based**
    - Tolerates staleness → suitable for longer TTL

- **Trade-off**
  - Short TTL → better freshness, lower cache efficiency
  - Long TTL → higher cache efficiency, more stale data
  - Requires balancing based on **data characteristics and consistency needs**

---

### Cache Stampede Prevention

- **Problem**
  - Many requests hit DB simultaneously on cache expiry

- **Mitigation**
  - TTL jitter → randomize expiry time
  - Probabilistic early refresh → refresh before expiry

- **Production enhancement**
  - Mutex/locking (Redis `SET NX`)
  - Only one request rebuilds cache

---

### RDS Design

- **Instance choice**
  - `db.t4g.medium`

- **Why**
  - Intentionally limited capacity to **surface bottlenecks**
  - Enables comparison across architectures

- **Insight**
  - Larger instance would hide DB bottleneck
  - Benchmark focuses on **system behavior**, not max performance

---

### Database Connection Management

- **In my project**
  - Each ECS task uses **connection pool** (SQLAlchemy)
  - Example: 18 tasks × 5 connections = ~90 connections

- **Problem**
  - Connection limit becomes bottleneck before compute

- **Solution (production)**
  - Use **PgBouncer**
    - Pool and multiplex connections
    - Reduce DB connection pressure

---

### Redis Deployment Choice

- **ElastiCache vs self-managed Redis**
  - ElastiCache → managed service (HA, failover, monitoring)
  - ECS Redis → **self-managed** (more control, more effort)

- **Why ElastiCache**
  - Stable and reliable for benchmark
  - Integrated metrics (CloudWatch)
  - No operational overhead

- **Trade-off**
  - Higher cost

---

### Redis Data Structure

- **Structure used**
  - Redis **String** storing a JSON-serialized list of telemetry records
  - Expiration controlled by TTL

- **Why**
  - Matches my use case: cache the full API response for a query
  - Simple read/write path and easy to debug
  - Good fit for read-heavy telemetry queries
  - TTL handles automatic expiry without extra invalidation logic

- **Trade-off**
  - Whole payload must be rewritten on update
  - Less efficient for partial updates, but acceptable because Redis is used as a response cache, not the source of truth

---

## Kafka / MSK Design

### Workload Decoupling

- **What Kafka is used for**
  - Primarily **write offloading**
  - Decouples API layer from database writes

- **How it works**
  - API receives request → publish message to Kafka → return response
  - Consumer processes message → writes to database asynchronously

- **Why**
  - Removes **synchronous DB dependency** from request path
  - Improves API latency and throughput
  - Smooths write spikes → avoids DB contention

---

### Data Flow & Consistency

- **Write path**
  - Application writes → Kafka topic → consumer → PostgreSQL

- **Consistency model**
  - **Eventual consistency**
    - API response ≠ immediate DB persistence
    - Data becomes available after consumer processes message

- **Trade-off**
  - Faster response time
  - Delayed data visibility

---

### Consumer Lag

- **What it is**
  - Difference between produced messages and processed messages

- **How I monitored**
  - CloudWatch metrics:
    - `EstimatedMaxTimeLag`
    - `SumOffsetLag`

- **Behavior in my project**
  - Lag is expected during peak load
  - API remains responsive despite backlog

- **Production consideration**
  - Sustained lag = consumers under-provisioned
  - Requires alerting and scaling

---

### Partition & Replication Design

- **Configuration**
  - Partitions: **3**
  - Replication factor: **3**

- **Why**
  - Partitions → define max parallel consumers
  - Replication → ensure durability and fault tolerance

- **Trade-off**
  - Partition count limits scalability
  - Cannot decrease partitions later → must plan ahead

---

### Message Failure Handling

- **Problem**
  - DB write failure (timeout, constraint error, etc.)

- **Strategy**
  - Retry with exponential backoff (for transient errors)
  - Use **Dead Letter Queue (DLQ)** for failed messages

- **Why**
  - Avoid blocking consumer on bad messages
  - Prevent data loss

- **Behavior**
  - Failed messages → moved to DLQ
  - Separate monitoring and reprocessing

---

### Delivery Guarantee

- **Kafka guarantee**
  - **At-least-once delivery**

- **Implication**
  - Messages may be processed more than once

- **Solution**
  - Ensure **idempotent consumer**
    - Use DB upsert (`INSERT ON CONFLICT DO UPDATE`)

- **Production enhancement**
  - Deduplication via message ID tracking
  - Exactly-once semantics (optional, higher complexity)

---

### Resilience Improvement

- **Compared to synchronous design**
  - API not blocked by DB
  - Can absorb traffic spikes via queue

- **Benefits**
  - Graceful degradation (queue buildup instead of failure)
  - Independent scaling:
    - API layer
    - Consumer layer

- **Result**
  - Smaller failure blast radius
  - Higher business continuity

---

### Scaling Strategy

- **At higher load (e.g., 10×)**
  - First bottleneck → consumer throughput
  - Second bottleneck → database write capacity

- **Mitigation**
  - Increase partitions → more parallel consumers
  - Scale consumers
  - Optimize DB:
    - Aurora
    - connection pooling (PgBouncer)
    - potential sharding

- **Kafka scaling**
  - Increase broker count
  - Upgrade MSK instance size

---

### Trade-off Summary

- **Benefits**
  - High throughput
  - Low API latency
  - Decoupled architecture
  - Strong resilience

- **Trade-offs**
  - Operational complexity (topics, partitions, offsets)
  - Higher infrastructure cost
  - Eventual consistency model

---
