#!/usr/bin/env bash
#
# Application-only release for the CONTAINERISED deployment.
#
#   ./deploy/ecs-release.sh <env> <frontend|backend> <docker-context-dir>
#
# It builds the image, pushes it to ECR, registers a NEW task definition
# revision that differs only by image tag, and rolls the ECS service onto it.
# CloudFormation is never invoked, so infrastructure cannot drift or be
# replaced by an application deployment.

set -euo pipefail

ENVIRONMENT="${1:?environment required}"
COMPONENT="${2:?component required}"
CONTEXT="${3:?docker context required}"
REGION="${AWS_REGION:-ap-south-1}"
TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD)}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
REPOSITORY="${REGISTRY}/${ENVIRONMENT}/${COMPONENT}"
FAMILY="${ENVIRONMENT}-${COMPONENT}"
CLUSTER="${ENVIRONMENT}-cluster"

echo "==> building ${REPOSITORY}:${TAG}"
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

docker build -t "${REPOSITORY}:${TAG}" -t "${REPOSITORY}:latest" "$CONTEXT"
docker push "${REPOSITORY}:${TAG}"
docker push "${REPOSITORY}:latest"

echo "==> registering new task definition revision"
aws ecs describe-task-definition --task-definition "$FAMILY" --region "$REGION" \
  --query taskDefinition > /tmp/current-td.json

# Keep only the fields register-task-definition accepts, and swap the image.
jq --arg IMAGE "${REPOSITORY}:${TAG}" '{
  family,
  taskRoleArn,
  executionRoleArn,
  networkMode,
  cpu,
  memory,
  requiresCompatibilities,
  runtimePlatform,
  containerDefinitions: (.containerDefinitions | map(.image = $IMAGE))
}' /tmp/current-td.json > /tmp/new-td.json

NEW_TD_ARN="$(aws ecs register-task-definition \
  --cli-input-json file:///tmp/new-td.json \
  --region "$REGION" \
  --query 'taskDefinition.taskDefinitionArn' --output text)"

echo "==> deploying $NEW_TD_ARN"
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "${ENVIRONMENT}-${COMPONENT}" \
  --task-definition "$NEW_TD_ARN" \
  --region "$REGION" >/dev/null

echo "==> waiting for the service to become stable"
aws ecs wait services-stable \
  --cluster "$CLUSTER" \
  --services "${ENVIRONMENT}-${COMPONENT}" \
  --region "$REGION"

echo "==> released ${COMPONENT} ${TAG} to ${ENVIRONMENT}"
