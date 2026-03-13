# Automated Architecture Benchmark - Kafka

[Back](../../README.md)

- [Automated Architecture Benchmark - Kafka](#automated-architecture-benchmark---kafka)
  - [Local - Testing](#local---testing)
  - [AWS ECR](#aws-ecr)
    - [Push ECR](#push-ecr)
  - [AWS Deployment](#aws-deployment)
    - [Terraform](#terraform)
    - [Init](#init)
  - [Remote Testing](#remote-testing)
  - [Grafana k6 Testing](#grafana-k6-testing)

---

## Local - Testing

```sh
# dev
docker compose -f app/compose_kafka/compose.kafka.yaml down -v && docker compose --env-file app/compose_kafka/.kafka.dev.env -f app/compose_kafka/compose.kafka.yaml up -d --build

# prod
docker compose -f app/compose_kafka/compose.kafka.yaml down -v && docker compose --env-file app/compose_kafka/.kafka.prod.env -f app/compose_kafka/compose.kafka.yaml up -d --build

# smoke
docker run --rm --name kafka_local_smoke --net=kafka_public_network -p 5665:5665 -e BASE_URL="http://nginx:8080" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/kafka_local_smoke.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_smoke.js

# read heavy
docker run --rm --name kafka_local_read --net=kafka_public_network -p 5665:5665 -e SOLUTION_ID="kafka" -e BASE_URL="http://nginx:8080" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/kafka_local_read.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_read.js

# write heavy
docker run --rm --name kafka_local_write --net=kafka_public_network -p 5665:5665 -e SOLUTION_ID="kafka" -e BASE_URL="http://nginx:8080" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/kafka_local_write.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_write.js

# mixed
docker run --rm --name kafka_local_mixed --net=kafka_public_network -p 5665:5665 -e SOLUTION_ID="Sol-kafka" -e BASE_URL="http://nginx:8080" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/kafka_local_mixed.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_mixed.js

python k6/pgdb_write_check.py

```

---

## AWS ECR

### Push ECR

- kafka

```sh
# Push
docker build -t fastapi_kafka app/fastapi_kafka

# tag
docker tag fastapi_kafka 099139718958.dkr.ecr.ca-central-1.amazonaws.com/auto-benchmark:fastapi-kafka

# push to docker
docker push 099139718958.dkr.ecr.ca-central-1.amazonaws.com/auto-benchmark:fastapi-kafka

```

- Init

```sh
# Push
docker build -t kafka_init app/kafka/init
# tag
docker tag kafka_init 099139718958.dkr.ecr.ca-central-1.amazonaws.com/auto-benchmark:kafka-init
# push to docker
docker push 099139718958.dkr.ecr.ca-central-1.amazonaws.com/auto-benchmark:kafka-init

```

- Consumer

```sh
# Push
docker build -t kafka_consumer app/kafka/consumer
# tag
docker tag kafka_consumer 099139718958.dkr.ecr.ca-central-1.amazonaws.com/auto-benchmark:kafka-consumer
# push to docker
docker push 099139718958.dkr.ecr.ca-central-1.amazonaws.com/auto-benchmark:kafka-consumer

```

- redis worker

```sh
# Push
docker build -t redis_outbox app/redis/worker
# tag
docker tag redis_outbox 099139718958.dkr.ecr.ca-central-1.amazonaws.com/auto-benchmark:redis-outbox
# push to docker
docker push 099139718958.dkr.ecr.ca-central-1.amazonaws.com/auto-benchmark:redis-outbox

```

---

## AWS Deployment

### Terraform

```sh
cd aws/kafka

terraform init -backend-config=backend.config

terraform fmt && terraform validate

terraform apply -auto-approve

terraform destroy -auto-approve

```

### Init

```sh
# init data via flyway
aws ecs run-task --cluster auto-benchmark-scale-cluster --task-definition auto-benchmark-scale-task-flyway --launch-type FARGATE --network-configuration "awsvpcConfiguration={subnets=[subnet-,subnet-,subnet-],securityGroups=[sg-]}"

# init msk
aws ecs run-task --cluster auto-benchmark-scale-cluster --task-definition iauto-benchmark-kafka-kafka-init --launch-type FARGATE --network-configuration "awsvpcConfiguration={subnets=[subnet-,subnet-,subnet-],securityGroups=[sg-]}"
```

---

## Remote Testing

```sh
# smoke
docker run --rm --name kafka_aws_smoke -p 5665:5665 -e BASE_URL="https://benchmark-kafka.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/kafka_aws_smoke.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_smoke.js

# read heavy
docker run --rm --name kafka_aws_read -p 5665:5665 -e SOLUTION_ID="kafka" -e BASE_URL="https://benchmark-kafka.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/kafka_aws_read.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_read.js

# write heavy
docker run --rm --name kafka_aws_write -p 5665:5665 -e SOLUTION_ID="kafka" -e BASE_URL="https://benchmark-kafka.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/kafka_aws_write.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_write.js

# mixed
docker run --rm --name kafka_aws_mixed -p 5665:5665 -e SOLUTION_ID="kafka" -e BASE_URL="https://benchmark-kafka.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/kafka_aws_mixed.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_mixed.js

python k6/pgdb_write_check.py

```

- breaking point

```sh
# read breaking point
docker run --rm --name kafka_aws_read_break -p 5665:5665 -e SOLUTION_ID="kafka" -e BASE_URL="https://benchmark-kafka.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/kafka_aws_read_break.html -e K6_WEB_DASHBOARD_PERIOD=3s -e RATE_TARGET=10000 -e STAGE_RAMP=60 -e MAX_VU=1000 -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_read.js

# write breaking point
docker run --rm --name kafka_aws_write_break -p 5665:5665 -e SOLUTION_ID="kafka" -e BASE_URL="https://benchmark-kafka.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/kafka_aws_write_break.html -e K6_WEB_DASHBOARD_PERIOD=3s -e RATE_TARGET=10000 -e STAGE_RAMP=60 -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_write.js

# mixed breaking point
docker run --rm --name kafka_aws_write_break -p 5665:5665 -e SOLUTION_ID="kafka" -e BASE_URL="https://benchmark-kafka.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/kafka_aws_write_break.html -e K6_WEB_DASHBOARD_PERIOD=3s -e RATE_READ_TARGET=10000 -e STAGE_RAMP=60 -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_write.js

```

---

## Grafana k6 Testing

```sh
# smoke
docker run --rm --name k6_kafka_aws_smoke --env-file ./k6/.env -e BASE_URL="https://benchmark-kafka.arguswatcher.net" -e SOLUTION_ID=kafka -e MAX_VU=100 -v ./k6/script:/script grafana/k6 cloud run --include-system-env-vars=true /script/test_smoke.js

# read
docker run --rm --name k6_kafka_aws_read --env-file ./k6/.env -e BASE_URL="https://benchmark-kafka.arguswatcher.net" -e SOLUTION_ID=kafka -e MAX_VU=100 -v ./k6/script:/script grafana/k6 cloud run --include-system-env-vars=true /script/test_hp_read.js

# write
docker run --rm --name k6_kafka_aws_write --env-file ./k6/.env -e BASE_URL="https://benchmark-kafka.arguswatcher.net" -e SOLUTION_ID=kafka -e MAX_VU=100 -v ./k6/script:/script grafana/k6 cloud run --include-system-env-vars=true /script/test_hp_write.js

# mixed
docker run --rm --name k6_kafka_aws_mixed --env-file ./k6/.env -e BASE_URL="https://benchmark-kafka.arguswatcher.net" -e SOLUTION_ID=kafka -e R_MAX_VU=50 -e W_MAX_VU=50 -v ./k6/script:/script grafana/k6 cloud run --include-system-env-vars=true /script/test_hp_mixed.js

```
