# AWS DevOps Assessment - Production-grade deployment of a Next.js + Python + PostgreSQL stack

This repository contains everything asked for in the assessment:

| Requirement | Where it lives |
|---|---|
| Cloud infrastructure (network, compute, database, monitoring, security) | `infrastructure/*.yaml` |
| Containerised deployment | ECS Fargate - `30-platform.yaml`, `40-ecs-services.yaml` |
| Non-containerised deployment | EC2 Auto Scaling + CodeDeploy - `50-ec2-noncontainer.yaml` |
| Infrastructure as Code | CloudFormation, layered stacks + `infrastructure/params/*.env` |
| CI/CD (GitHub Actions) | `.github/workflows/` |
| CI/CD (AWS native) | CodePipeline + CodeBuild + CodeDeploy - `70-aws-native-pipeline.yaml` |
| App vs infra separation | Path-filtered workflows, see `docs/04-cicd-workflow.md` |
| Secrets management | Secrets Manager + IAM, see `docs/05-security.md` |
| Documentation | `docs/` |

## Repository layout

```
.
|-- apps/
|   |-- frontend/            Next.js 15 application (Dockerfile + standalone build)
|   `-- backend/             FastAPI application (Dockerfile + tests)
|-- infrastructure/
|   |-- 00-github-oidc.yaml  GitHub OIDC provider + CI role (deploy once)
|   |-- 10-network.yaml      VPC, subnets, NAT, security groups
|   |-- 20-database.yaml     RDS PostgreSQL + Secrets Manager
|   |-- 30-platform.yaml     ECR, ALB, ECS cluster, IAM roles, log groups
|   |-- 40-ecs-services.yaml Fargate task definitions, services, auto scaling
|   |-- 50-ec2-noncontainer.yaml  ALB, ASG, CodeDeploy (non-containerised)
|   |-- 60-monitoring.yaml   Alarms, SNS, dashboard
|   |-- 70-aws-native-pipeline.yaml  CodePipeline + CodeBuild (optional)
|   |-- deploy.sh            Thin wrapper around "aws cloudformation deploy"
|   `-- params/              dev.env / staging.env / prod.env
|-- deploy/
|   |-- appspec.yml          CodeDeploy lifecycle definition
|   |-- scripts/             CodeDeploy lifecycle hooks
|   |-- bootstrap-images.sh First-ever image push
|   |-- ecs-release.sh       Application-only release for ECS
|   |-- build-ec2-bundle.sh  Application-only release for EC2
|   `-- buildspec-backend.yml  CodeBuild instructions
|-- docs/                    Architecture, security, rollback documentation
`-- .github/workflows/       GitHub Actions pipelines
```

## Quick start

```bash
export AWS_REGION=ap-south-1

# 1. One-time: CI/CD identity
aws cloudformation deploy --template-file infrastructure/00-github-oidc.yaml \
  --stack-name github-oidc --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides GitHubOrg=<your-org> GitHubRepo=aws-devops-assessment

# 2. Infrastructure, in order
./infrastructure/deploy.sh dev 10-network.yaml
./infrastructure/deploy.sh dev 20-database.yaml
./infrastructure/deploy.sh dev 30-platform.yaml

# 3. First container images (the ECR repositories now exist)
./deploy/bootstrap-images.sh dev

# 4. Workloads
./infrastructure/deploy.sh dev 40-ecs-services.yaml
./infrastructure/deploy.sh dev 50-ec2-noncontainer.yaml
./infrastructure/deploy.sh dev 60-monitoring.yaml
```

The full, ordered, copy-paste procedure is in `docs/03-deployment-flow.md`.
