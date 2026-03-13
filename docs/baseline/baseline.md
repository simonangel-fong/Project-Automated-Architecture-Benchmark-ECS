# Automated Architecture Benchmark - Baseline

[Back](../../README.md)

- [Automated Architecture Benchmark - Baseline](#automated-architecture-benchmark---baseline)
  - [Local Development](#local-development)
    - [Initialize Environment](#initialize-environment)
    - [Unit Test](#unit-test)
  - [Local Testing](#local-testing)
  - [AWS ECR](#aws-ecr)
    - [Create ECR Repo](#create-ecr-repo)
    - [Push ECR](#push-ecr)
  - [AWS Deployment](#aws-deployment)
  - [Remote Testing](#remote-testing)
  - [Grafana k6 Testing](#grafana-k6-testing)

---

## Local Development

### Initialize Environment

```sh
# init
cd app/fastapi_baseline
python -m venv .venv

.venv\Scripts\activate.bat

python.exe -m pip install --upgrade pip
pip install fastapi "uvicorn[standard]" "SQLAlchemy[asyncio]" asyncpg pydantic python-dotenv pydantic-settings pytest pytest-asyncio httpx redis aiokafka

pip freeze > requirements.txt
# uvloop==0.22.1

uvicorn app.main:app --reload
```

---

### Unit Test

```sh
cd app/fastapi_baseline

# unit test
pytest
```

---

## Local Testing

```sh
# dev
docker compose -f app/compose_baseline/compose.baseline.yaml down -v && docker compose --env-file app/compose_baseline/.baseline.dev.env -f app/compose_baseline/compose.baseline.yaml up -d --build

# prod
docker compose -f app/compose_baseline/compose.baseline.yaml down -v && docker compose --env-file app/compose_baseline/.baseline.prod.env -f app/compose_baseline/compose.baseline.yaml up -d --build

# smoke
docker run --rm --name baseline_local_smoke --net=baseline_public_network -p 5665:5665 -e BASE_URL="http://nginx:8080" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/baseline_local_smoke.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_smoke.js

# Stress testing
docker run --rm --name baseline_local_read_stress --net=baseline_public_network -p 5665:5665 -e BASE_URL="http://nginx:8080" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/baseline_local_read_stress.html -e K6_WEB_DASHBOARD_PERIOD=3s -e STAGE_RAMP=3 -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/stress_testing_read.js

# read heavy
docker run --rm --name baseline_local_read --net=baseline_public_network -p 5665:5665 -e SOLUTION_ID="baseline" -e BASE_URL="http://nginx:8080" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/baseline_local_read.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_read.js

# write heavy
docker run --rm --name test_hp_write --net=baseline_public_network -p 5665:5665 -e SOLUTION_ID="baseline" -e BASE_URL="http://nginx:8080" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/baseline_local_write.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_write.js

# mixed
docker run --rm --name test_hp_mixed --net=baseline_public_network -p 5665:5665 -e SOLUTION_ID="baseline" -e BASE_URL="http://nginx:8080" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/baseline_local_mixed.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_mixed.js

python k6/pgdb_write_check.py
```

---

## AWS ECR

### Create ECR Repo

```sh
# login
aws ecr get-login-password --region ca-central-1 | docker login --username AWS --password-stdin 099139718958.dkr.ecr.ca-central-1.amazonaws.com
# Login Succeeded

# Create repo
aws ecr create-repository --repository-name auto-benchmark --region ca-central-1

```

---

### Push ECR

- Baseline

```sh
# Push
docker build -t fastapi_baseline app/fastapi_baseline
# tag
docker tag fastapi_baseline 099139718958.dkr.ecr.ca-central-1.amazonaws.com/auto-benchmark:fastapi-baseline
# push to docker
docker push 099139718958.dkr.ecr.ca-central-1.amazonaws.com/auto-benchmark:fastapi-baseline

```

---

- Flyway

```sh
# push image
docker build -t flyway app/flyway
# tag
docker tag flyway 099139718958.dkr.ecr.ca-central-1.amazonaws.com/auto-benchmark:flyway
# push to docker
docker push 099139718958.dkr.ecr.ca-central-1.amazonaws.com/auto-benchmark:flyway

```

---

## AWS Deployment

```sh
cd aws/baseline

terraform init -backend-config=backend.config

terraform fmt && terraform validate

terraform apply -auto-approve

# execute flyway to init rds
aws ecs run-task --cluster auto-benchmark-baseline-cluster --task-definition auto-benchmark-baseline-task-flyway --launch-type FARGATE --network-configuration "awsvpcConfiguration={subnets=[subnet-,subnet-,subnet-],securityGroups=[sg-]}"

terraform destroy -auto-approve

```

---

## Remote Testing

```sh
# smoke
docker run --rm --name baseline_aws_smoke -p 5665:5665 -e BASE_URL="https://benchmark-baseline.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/baseline_aws_smoke.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_smoke.js

# Stress testing
docker run --rm --name baseline_aws_read_stress -p 5665:5665 -e BASE_URL="https://benchmark-baseline.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/baseline_aws_read_stress.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/stress_testing_read.js

# constant read
docker run --rm --name baseline_aws_constant_read -p 5665:5665 -e BASE_URL="https://benchmark-baseline.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_PERIOD=3s -e RATE_TARGET=50 -e STAGE_CONSTANT=60 -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/constant_read.js


# read heavy
docker run --rm --name baseline_aws_read -p 5665:5665 -e SOLUTION_ID="baseline" -e BASE_URL="https://benchmark-baseline.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/baseline_aws_read.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_read.js

# write heavy
docker run --rm --name baseline_aws_write -p 5665:5665 -e SOLUTION_ID="baseline" -e BASE_URL="https://benchmark-baseline.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/baseline_aws_write.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_write.js

# mixed
docker run --rm --name baseline_aws_mixed -p 5665:5665 -e SOLUTION_ID="baseline" -e BASE_URL="https://benchmark-baseline.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/baseline_aws_mixed.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_mixed.js

```

---

## Grafana k6 Testing

```sh
# smoke
docker run --rm --name k6_baseline_aws_smoke --env-file ./k6/.env -e BASE_URL="https://benchmark-baseline.arguswatcher.net" -e SOLUTION_ID=baseline -e MAX_VU=100 -v ./k6/script:/script grafana/k6 cloud run --include-system-env-vars=true /script/test_smoke.js

# read
docker run --rm --name k6_baseline_aws_smoke --env-file ./k6/.env -e BASE_URL="https://benchmark-baseline.arguswatcher.net" -e SOLUTION_ID=baseline -e MAX_VU=100 -v ./k6/script:/script grafana/k6 cloud run --include-system-env-vars=true /script/test_hp_read.js

# write
docker run --rm --name k6_baseline_aws_write --env-file ./k6/.env -e BASE_URL="https://benchmark-baseline.arguswatcher.net" -e SOLUTION_ID=baseline -e MAX_VU=100 -v ./k6/script:/script grafana/k6 cloud run --include-system-env-vars=true /script/test_hp_write.js
```
