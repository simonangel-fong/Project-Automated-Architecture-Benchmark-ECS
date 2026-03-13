# Automated Architecture Benchmark - Scale

[Back](../../README.md)

- [Automated Architecture Benchmark - Scale](#automated-architecture-benchmark---scale)
  - [Local - Testing](#local---testing)
  - [AWS](#aws)
  - [Remote Testing](#remote-testing)
  - [Grafana k6 Testing](#grafana-k6-testing)

---

## Local - Testing

```sh
# dev
docker compose -f app/compose_scale/compose.scale.yaml down -v && docker compose --env-file app/compose_scale/.scale.dev.env -f app/compose_scale/compose.scale.yaml up -d --build

# prod
docker compose -f app/compose_scale/compose.scale.yaml down -v && docker compose --env-file app/compose_scale/.scale.prod.env -f app/compose_scale/compose.scale.yaml up -d --build

# smoke
docker run --rm --name scale_local_smoke --net=scale_public_network -p 5665:5665 -e BASE_URL="http://nginx:8080" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/scale_local_smoke.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_smoke.js

# Read Stress testing
docker run --rm --name scale_local_read_stress --net=scale_public_network -p 5665:5665 -e BASE_URL="http://nginx:8080" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/scale_local_read_stress.html -e K6_WEB_DASHBOARD_PERIOD=3s -e STAGE_RAMP=1 -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/stress_testing_read.js

# Write Stress testing
docker run --rm --name scale_local_write_stress --net=scale_public_network -p 5665:5665 -e BASE_URL="http://nginx:8080" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/scale_local_write_stress.html -e K6_WEB_DASHBOARD_PERIOD=3s -e STAGE_RAMP=1 -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/stress_testing_write.js

# read heavy
docker run --rm --name scale_local_read --net=scale_public_network -p 5665:5665 -e SOLUTION_ID="scale" -e BASE_URL="http://nginx:8080" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/scale_local_read.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_read.js

# write heavy
docker run --rm --name scale_local_write --net=scale_public_network -p 5665:5665 -e SOLUTION_ID="scale" -e BASE_URL="http://nginx:8080" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/scale_local_write.html -e K6_WEB_DASHBOARD_PERIOD=3s  -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_write.js

# mixed
docker run --rm --name scale_local_mixed --net=scale_public_network -p 5665:5665 -e SOLUTION_ID="scale" -e BASE_URL="http://nginx:8080" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/scale_local_mixed.html -e K6_WEB_DASHBOARD_PERIOD=3s  -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_mixed.js

python k6/pgdb_write_check.py
```

---

## AWS

```sh
cd aws/scale

terraform init -backend-config=backend.config

terraform fmt && terraform validate

terraform apply -auto-approve

aws ecs run-task --cluster auto-benchmark-scale-cluster --task-definition auto-benchmark-scale-task-flyway --launch-type FARGATE --network-configuration "awsvpcConfiguration={subnets=[subnet-,subnet-,subnet-],securityGroups=[sg-]}"

terraform destroy -auto-approve

```

## Remote Testing

```sh
# smoke
docker run --rm --name scale_aws_smoke -p 5667:5665 -e BASE_URL="https://benchmark-scale.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/scale_aws_smoke.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_smoke.js

# constant read
docker run --rm --name scale_aws_constant_read -p 5665:5665 -e BASE_URL="https://benchmark-scale.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_PERIOD=3s -e RATE_TARGET=1200 -e STAGE_CONSTANT=60 -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/constant_read.js


# Stress testing
docker run --rm --name scale_aws_read_stress -p 5665:5665 -e BASE_URL="https://benchmark-scale.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/scale_aws_read_stress.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/stress_testing_read.js



# read heavy
docker run --rm --name scale_aws_read -p 5665:5665 -e SOLUTION_ID="scale" -e BASE_URL="https://benchmark-scale.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/scale_aws_read.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_read.js

# write heavy
docker run --rm --name scale_aws_write -p 5665:5665 -e SOLUTION_ID="scale" -e BASE_URL="https://benchmark-scale.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/scale_aws_write.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_write.js

# mixed
docker run --rm --name scale_aws_mixed -p 5665:5665 -e SOLUTION_ID="scale" -e BASE_URL="https://benchmark-scale.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/scale_aws_mixed.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_mixed.js
```

---

## Grafana k6 Testing

```sh
# smoke
docker run --rm --name k6_scale_aws_smoke --env-file ./k6/.env -e BASE_URL="https://benchmark-scale.arguswatcher.net" -e SOLUTION_ID=scale -e MAX_VU=100 -v ./k6/script:/script grafana/k6 cloud run --include-system-env-vars=true /script/test_smoke.js

# read
docker run --rm --name k6_scale_aws_read --env-file ./k6/.env -e BASE_URL="https://benchmark-scale.arguswatcher.net" -e SOLUTION_ID=scale -e MAX_VU=100 -v ./k6/script:/script grafana/k6 cloud run --include-system-env-vars=true /script/test_hp_read.js

# write
docker run --rm --name k6_scale_aws_write --env-file ./k6/.env -e BASE_URL="https://benchmark-scale.arguswatcher.net" -e SOLUTION_ID=scale -e MAX_VU=100 -v ./k6/script:/script grafana/k6 cloud run --include-system-env-vars=true /script/test_hp_write.js
```
