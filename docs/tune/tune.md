# Project: IOT Mgnt Telemetry Cloud Native - Tune

[Back](../../README.md)

- [Project: IOT Mgnt Telemetry Cloud Native - Tune](#project-iot-mgnt-telemetry-cloud-native---tune)
  - [Local Testing](#local-testing)
  - [AWS Deployment](#aws-deployment)
  - [Remote Testing](#remote-testing)

---

## Local Testing

```sh
# dev
docker compose -f app/compose_tune/compose.tune.yaml down -v && docker compose --env-file app/compose_tune/.tune.dev.env -f app/compose_tune/compose.tune.yaml up -d --build

# staging
docker compose -f app/compose_tune/compose.tune.yaml down -v && docker compose --env-file app/compose_tune/.tune.staging.env -f app/compose_tune/compose.tune.yaml up -d --build

# prod
docker compose -f app/compose_tune/compose.tune.yaml down -v && docker compose --env-file app/compose_tune/.tune.prod.env -f app/compose_tune/compose.tune.yaml up -d --build

# smoke
docker run --rm --name tune_local_smoke --net=tune_public_network -p 5665:5665 -e BASE_URL="http://nginx:8080" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/tune_local_smoke.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_smoke.js

# read heavy
docker run --rm --name tune_local_read --net=tune_public_network -p 5665:5665 -e SOLUTION_ID="tune" -e BASE_URL="http://nginx:8080" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/tune_local_read.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_read.js

# write heavy
docker run --rm --name test_hp_write --net=tune_public_network -p 5665:5665 -e SOLUTION_ID="tune" -e BASE_URL="http://nginx:8080" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/tune_local_write.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_write.js

# mixed
docker run --rm --name test_hp_mixed --net=tune_public_network -p 5665:5665 -e SOLUTION_ID="tune" -e BASE_URL="http://nginx:8080" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/tune_local_mixed.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_mixed.js

python k6/pgdb_write_check.py
```

---

## AWS Deployment

```sh
cd aws/tune

terraform init -backend-config=backend.config

tfsec .
terraform fmt && terraform validate

terraform apply -auto-approve

# execute flyway to init rds
aws ecs run-task --cluster auto-benchmark-tune-cluster --task-definition auto-benchmark-tune-task-flyway --launch-type FARGATE --network-configuration "awsvpcConfiguration={subnets=[subnet-,subnet-,subnet-],securityGroups=[sg-]}"

terraform destroy -auto-approve

```

---

## Remote Testing

```sh
# smoke
docker run --rm --name tune_aws_smoke -p 5666:5665 -e BASE_URL="https://benchmark-tune.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/tune_aws_smoke.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_smoke.js

# read heavy
docker run --rm --name tune_aws_read -p 5666:5665 -e SOLUTION_ID="tune" -e BASE_URL="https://benchmark-tune.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/tune_aws_read.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_read.js

# write heavy
docker run --rm --name tune_aws_write -p 5666:5665 -e SOLUTION_ID="tune" -e BASE_URL="https://benchmark-tune.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/tune_aws_write.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_write.js

# mixed
docker run --rm --name tune_aws_mixed -p 5666:5665 -e SOLUTION_ID="tune" -e BASE_URL="https://benchmark-tune.arguswatcher.net" -e K6_WEB_DASHBOARD=true -e K6_WEB_DASHBOARD_EXPORT=/report/tune_aws_mixed.html -e K6_WEB_DASHBOARD_PERIOD=3s -v ./k6/script:/script -v ./k6/report:/report/ grafana/k6 run /script/test_hp_mixed.js

```
