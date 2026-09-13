#!/usr/bin/env bash
#
# Deploys ONE CloudFormation stack for ONE environment.
#
#   ./infrastructure/deploy.sh <dev|staging|prod> <template-file-name>
#
# Example:
#   ./infrastructure/deploy.sh dev 10-network.yaml
#
# The script reads infrastructure/params/<env>.env and automatically passes
# only the parameters that the chosen template actually declares, so a single
# parameter file can serve every stack.

set -euo pipefail

ENVIRONMENT="${1:-}"
TEMPLATE_FILE="${2:-}"
REGION="${AWS_REGION:-ap-south-1}"

if [[ -z "$ENVIRONMENT" || -z "$TEMPLATE_FILE" ]]; then
  echo "usage: $0 <dev|staging|prod> <template-file-name>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_PATH="$SCRIPT_DIR/$TEMPLATE_FILE"
PARAM_FILE="$SCRIPT_DIR/params/${ENVIRONMENT}.env"

[[ -f "$TEMPLATE_PATH" ]] || { echo "template not found: $TEMPLATE_PATH" >&2; exit 1; }
[[ -f "$PARAM_FILE" ]]    || { echo "params not found: $PARAM_FILE"     >&2; exit 1; }

# dev + 10-network.yaml  ->  dev-network
SHORT_NAME="$(basename "$TEMPLATE_FILE" .yaml | sed 's/^[0-9]*-//')"
STACK_NAME="${ENVIRONMENT}-${SHORT_NAME}"

echo "==> stack      : $STACK_NAME"
echo "==> template   : $TEMPLATE_FILE"
echo "==> region     : $REGION"

# Ask CloudFormation which parameters this template accepts.
ALLOWED="$(aws cloudformation get-template-summary \
  --template-body "file://$TEMPLATE_PATH" \
  --query 'Parameters[].ParameterKey' --output text --region "$REGION")"

OVERRIDES=()
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%$'\r'}"
  [[ -z "$line" || "$line" == \#* ]] && continue
  key="${line%%=*}"
  for allowed_key in $ALLOWED; do
    if [[ "$allowed_key" == "$key" ]]; then
      OVERRIDES+=("$line")
      break
    fi
  done
done < "$PARAM_FILE"

echo "==> parameters : ${OVERRIDES[*]:-none}"

aws cloudformation deploy \
  --template-file "$TEMPLATE_PATH" \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset \
  --tags "Environment=$ENVIRONMENT" "Project=aws-devops-assessment" \
  ${OVERRIDES[@]+--parameter-overrides "${OVERRIDES[@]}"}

echo "==> outputs:"
aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" \
  --query 'Stacks[0].Outputs[].[OutputKey,OutputValue]' --output table
