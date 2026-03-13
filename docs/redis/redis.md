# Automated Architecture Benchmark - Redis

[Back](../../README.md)

- [Automated Architecture Benchmark - Redis](#automated-architecture-benchmark---redis)
  - [Local - Testing](#local---testing)
  - [AWS ECR](#aws-ecr)
    - [Push ECR](#push-ecr)
  - [AWS Deployment](#aws-deployment)
  - [Remote Testing](#remote-testing)
  - [Grafana k6 Testing](#grafana-k6-testing)

---

## Local - Testing

```sh
# dev
docker compose -f app/compose_redis/compose.redis.yaml down -v && docker compose --env-file app/compose_redis/.redis.dev.env -f app/compose_redis/compose.redis.yaml up -d --build

# prod
docker compose -f app/compose_redis/compose.redis.yaml down -v && docker compose --env-file app/compose_redis/.redis.prod.env -f app/compose_redis/compose.redis.yaml up -d --build

# smoke
docker run --rm --name redis_local_smoke --net=redis_public_network -p 5665:5665 -e BASE_URL="http://nginx:8080" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/redis_local_smoke.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_smoke.js

# read heavy
docker run --rm --name redis_local_read --net=redis_public_network -p 5665:5665 -e SOLUTION_ID="redis" -e BASE_URL="http://nginx:8080" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/redis_local_read.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_read.js

# write heavy
docker run --rm --name redis_local_write --net=redis_public_network -p 5665:5665 -e SOLUTION_ID="redis" -e BASE_URL="http://nginx:8080" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/redis_local_write.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_write.js

# mixed
docker run --rm --name redis_local_mixed --net=redis_public_network -p 5665:5665 -e SOLUTION_ID="redis" -e BASE_URL="http://nginx:8080" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/redis_local_mixed.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_mixed.js

python k6/pgdb_write_check.py

```

---

## AWS ECR

### Push ECR

- redis

```sh
# Push
docker build -t fastapi_redis app/fastapi_redis

# tag
docker tag fastapi_redis 099139718958.dkr.ecr.ca-central-1.amazonaws.com/auto-benchmark:fastapi-redis

# push to docker
docker push 099139718958.dkr.ecr.ca-central-1.amazonaws.com/auto-benchmark:fastapi-redis

```

## AWS Deployment

```sh
cd aws/redis

terraform init -backend-config=backend.config

terraform fmt && terraform validate

terraform apply -auto-approve

# init data via flyway
aws ecs run-task --cluster auto-benchmark-redis-cluster --task-definition auto-benchmark-redis-task-flyway --launch-type FARGATE --network-configuration "awsvpcConfiguration={subnets=[subnet-,subnet-,subnet-],securityGroups=[sg-]}"

terraform destroy -auto-approve

```

## Remote Testing

```sh
# smoke
docker run --rm --name redis_aws_smoke -p 5665:5665 -e BASE_URL="https://benchmark-redis.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/redis_aws_smoke.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_smoke.js

# read heavy
docker run --rm --name redis_aws_read -p 5665:5665 -e SOLUTION_ID="redis" -e BASE_URL="https://benchmark-redis.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/redis_aws_read.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_read.js

# write heavy
docker run --rm --name redis_aws_write -p 5665:5665 -e SOLUTION_ID="redis" -e BASE_URL="https://benchmark-redis.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/redis_aws_write.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_write.js

# mixed
docker run --rm --name redis_aws_mixed -p 5665:5665 -e SOLUTION_ID="redis" -e BASE_URL="https://benchmark-redis.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/redis_aws_mixed.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_mixed.js

python k6/pgdb_write_check.py
```

---

## Grafana k6 Testing

```sh
# smoke
docker run --rm --name k6_redis_aws_smoke --env-file ./k6/.env -e BASE_URL="https://benchmark-redis.arguswatcher.net" -e SOLUTION_ID=redis -e MAX_VU=100 -v ./k6/script:/script grafana/k6 cloud run --include-system-env-vars=true /script/test_smoke.js

# read
docker run --rm --name k6_redis_aws_read --env-file ./k6/.env -e BASE_URL="https://benchmark-redis.arguswatcher.net" -e SOLUTION_ID=redis -e MAX_VU=100 -v ./k6/script:/script grafana/k6 cloud run --include-system-env-vars=true /script/test_hp_read.js

# write
docker run --rm --name k6_redis_aws_write --env-file ./k6/.env -e BASE_URL="https://benchmark-redis.arguswatcher.net" -e SOLUTION_ID=redis -e MAX_VU=100 -v ./k6/script:/script grafana/k6 cloud run --include-system-env-vars=true /script/test_hp_write.js
```
