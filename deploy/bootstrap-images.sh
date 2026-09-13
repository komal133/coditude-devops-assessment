#!/usr/bin/env bash
#
# FIRST-TIME ONLY. Builds both images and pushes them as ":latest" so that the
# ECS services (40-ecs-services.yaml) have something to start from.
# After this, every release goes through the CI/CD pipeline.
#
#   ./deploy/bootstrap-images.sh <env>

set -euo pipefail

ENVIRONMENT="${1:?environment required}"
REGION="${AWS_REGION:-ap-south-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

for component in frontend backend; do
  repo="${REGISTRY}/${ENVIRONMENT}/${component}"
  echo "==> building and pushing ${repo}:latest"
  docker build -t "${repo}:latest" "apps/${component}"
  docker push "${repo}:latest"
done

echo "==> bootstrap images pushed"
