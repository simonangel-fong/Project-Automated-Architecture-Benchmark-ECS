

## Upload Video file to s3

```sh
# Create a bucket
aws s3 mb s3://ecs-benchmark.arguswatcher.net
# make_bucket: ecs-benchmark.arguswatcher.net

# confirm
aws s3 ls
# 2026-03-13 15:29:38 ecs-benchmark.arguswatcher.net

# upload
aws s3 cp app/html/video s3://ecs-benchmark.arguswatcher.net/video --recursive --exclude * --include *.mp4
# upload: app\html\video\github_action.mp4 to s3://ecs-benchmark.arguswatcher.net/video/github_action.mp4
# upload: app\html\video\grafana_metrics.mp4 to s3://ecs-benchmark.arguswatcher.net/video/grafana_metrics.mp4
# upload: app\html\video\project_video.mp4 to s3://ecs-benchmark.arguswatcher.net/video/project_video.mp4

aws s3 ls s3://ecs-benchmark.arguswatcher.net
# PRE video/
aws s3 ls s3://ecs-benchmark.arguswatcher.net --recursive
# 2026-03-13 15:30:30    1011278 video/github_action.mp4
# 2026-03-13 15:30:30   27702309 video/grafana_metrics.mp4
# 2026-03-13 15:30:30   41088296 video/project_video.mp4

# delete object
aws s3 rm s3://ecs-benchmark.arguswatcher.net/video/github_action.mp4
# delete: s3://ecs-benchmark.arguswatcher.net/video/github_action.mp4

# delete an folder
aws s3 rm s3://ecs-benchmark.arguswatcher.net/video/ --recursive
# delete: s3://ecs-benchmark.arguswatcher.net/video/grafana_metrics.mp4
# delete: s3://ecs-benchmark.arguswatcher.net/video/project_video.mp4

# delete a bucket
aws s3 rb s3://ecs-benchmark.arguswatcher.net --force
# delete: s3://ecs-benchmark.arguswatcher.net/video/grafana_metrics.mp4
# delete: s3://ecs-benchmark.arguswatcher.net/video/project_video.mp4
# delete: s3://ecs-benchmark.arguswatcher.net/video/github_action.mp4
# remove_bucket: ecs-benchmark.arguswatcher.net

aws s3 ls s3://ecs-benchmark.arguswatcher.net/
```

## Local TF

```sh
terraform -chdir=aws/web init --backend-config=backend.config
terraform -chdir=aws/web fmt && terraform -chdir=aws/web validate
terraform -chdir=aws/web apply -auto-approve
```