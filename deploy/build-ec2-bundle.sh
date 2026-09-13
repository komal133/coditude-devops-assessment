#!/usr/bin/env bash
#
# Builds the CodeDeploy bundle for the NON-CONTAINERISED deployment and
# uploads it to the versioned S3 artifact bucket.
#
#   ./deploy/build-ec2-bundle.sh <env>

set -euo pipefail

ENVIRONMENT="${1:?environment required}"
REGION="${AWS_REGION:-ap-south-1}"
TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD)}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${ENVIRONMENT}-app-artifacts-${ACCOUNT_ID}-${REGION}"
BUNDLE_DIR="build/bundle"

rm -rf build
mkdir -p "$BUNDLE_DIR/backend" "$BUNDLE_DIR/frontend"

echo "==> packaging backend"
cp apps/backend/app.py apps/backend/requirements.txt "$BUNDLE_DIR/backend/"

echo "==> building frontend (standalone output)"
pushd apps/frontend >/dev/null
npm install
npm run build
popd >/dev/null

cp -r apps/frontend/.next/standalone/. "$BUNDLE_DIR/frontend/"
mkdir -p "$BUNDLE_DIR/frontend/.next"
cp -r apps/frontend/.next/static "$BUNDLE_DIR/frontend/.next/static"
if [ -d apps/frontend/public ]; then
  cp -r apps/frontend/public "$BUNDLE_DIR/frontend/public"
fi

echo "==> adding CodeDeploy metadata"
cp deploy/appspec.yml "$BUNDLE_DIR/appspec.yml"
cp -r deploy/scripts "$BUNDLE_DIR/scripts"
chmod +x "$BUNDLE_DIR"/scripts/*.sh

pushd "$BUNDLE_DIR" >/dev/null
zip -qr "../app-${TAG}.zip" .
popd >/dev/null

echo "==> uploading to s3://${BUCKET}/releases/app-${TAG}.zip"
aws s3 cp "build/app-${TAG}.zip" "s3://${BUCKET}/releases/app-${TAG}.zip" --region "$REGION"

echo "==> creating CodeDeploy deployment"
DEPLOYMENT_ID="$(aws deploy create-deployment \
  --application-name "${ENVIRONMENT}-app" \
  --deployment-group-name "${ENVIRONMENT}-app-dg" \
  --s3-location "bucket=${BUCKET},key=releases/app-${TAG}.zip,bundleType=zip" \
  --description "Release ${TAG}" \
  --region "$REGION" \
  --query deploymentId --output text)"

echo "==> deployment ${DEPLOYMENT_ID} started; waiting for completion"
aws deploy wait deployment-successful --deployment-id "$DEPLOYMENT_ID" --region "$REGION"
echo "==> released ${TAG} to ${ENVIRONMENT} (EC2)"
