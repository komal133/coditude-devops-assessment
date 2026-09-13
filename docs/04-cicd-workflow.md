# 4. CI/CD workflow

## The separation requirement

> Application code changes should trigger only application deployment.
> Infrastructure should not be modified or redeployed during application-only
> deployments.

This is enforced in three independent ways:

1. **Path filters.** `infra.yml` triggers only on `infrastructure/**`. The
   application workflows trigger only on `apps/**` and their own deploy
   scripts. A commit touching only application code cannot start the
   infrastructure workflow.
2. **Different AWS APIs.** Application workflows call `ecr`, `ecs` and
   `codedeploy` only. The string `cloudformation` does not appear in them.
   Infrastructure workflows call `cloudformation deploy` only.
3. **Different state.** An application release creates a new *task definition
   revision* (ECS) or a new *S3 object version* (EC2). Neither is a
   CloudFormation resource, so no stack drift and no resource replacement can
   result from a release.

If the reviewer asks "prove it", run an application deployment and then
`aws cloudformation describe-stack-events --stack-name dev-ecs-services` - the
most recent event will still be from the original infrastructure deployment.

## Workflows

| File | Trigger | Does |
|---|---|---|
| `infra.yml` | `infrastructure/**` on `main`, or manual | cfn-lint, then deploy dev -> staging -> prod |
| `app-backend.yml` | `apps/backend/**` | pytest, build image, push to ECR, roll ECS service |
| `app-frontend.yml` | `apps/frontend/**` | `next build` check, build image, push, roll ECS service |
| `app-ec2.yml` | `apps/**`, `deploy/scripts/**` | build bundle, upload to S3, CodeDeploy release |
| `reusable-ec2-deploy.yml` | called by `app-ec2.yml` | one definition reused by three environments |
| `rollback.yml` | manual | roll an ECS service back to any task definition revision |

## Promotion and approvals

Each environment is a GitHub **Environment** (`dev`, `staging`, `prod`). Add
required reviewers to `staging` and `prod` in *Settings > Environments*; the
job then pauses until a human approves. `dev` stays automatic.

## Authentication: no AWS keys in GitHub

`aws-actions/configure-aws-credentials@v4` exchanges the GitHub OIDC token for
short-lived AWS credentials by assuming `github-actions-<repo>`. The role's
trust policy accepts only tokens whose `sub` claim matches
`repo:<org>/<repo>:*`, so no other repository can use it. The only repository
variable needed is `AWS_ROLE_ARN` - and it is not a secret.

## AWS-native pipeline

`70-aws-native-pipeline.yaml` provisions CodePipeline (source from GitHub via a
CodeConnections connection) -> CodeBuild (`deploy/buildspec-backend.yml`) ->
ECS deploy action. It is application-only by construction: the ECS deploy
action consumes `imagedefinitions.json` and updates the service, exactly like
the GitHub Actions path. CodeDeploy (in `50-ec2-noncontainer.yaml`) is the
second AWS-native deployment service in use.
