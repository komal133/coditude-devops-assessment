# 1. Architecture overview

## Design goals

| Goal | How it is met |
|---|---|
| Production-ready | Layered CloudFormation stacks, immutable image tags, health-gated releases, automatic rollback |
| Scalable | ALB + ECS service auto scaling (CPU target tracking) and EC2 Auto Scaling Group |
| Secure | Private subnets for every workload, no public IPs on compute, secrets in Secrets Manager, OIDC instead of static AWS keys, encrypted storage |
| Highly available | Two Availability Zones for subnets, ALB, ECS tasks, ASG instances and (in prod) Multi-AZ RDS |

## Request path

```
                         Internet
                             |
              +--------------+--------------+
              |                             |
    ALB (containerised)            ALB (non-containerised)
    dev-ecs-alb                    dev-ec2-alb
              |                             |
   path /api/* -> backend TG       path /api/* -> backend TG
   default     -> frontend TG      default     -> frontend TG
              |                             |
      ECS Fargate tasks               EC2 ASG instances
      (private app subnets)           (private app subnets)
              |                             |
              +--------------+--------------+
                             |
                 RDS PostgreSQL (private DB subnets)
                 credentials in AWS Secrets Manager
```

Both deployment styles are deliberately identical from the browser's point of
view: the frontend calls `/api/...` on its own origin and the load balancer
routes that prefix to the Python backend. No CORS configuration, no backend
hostname baked into the frontend build.

## Network layout (per environment)

| Tier | Subnets | Internet access |
|---|---|---|
| Public | `10.x.1.0/24`, `10.x.2.0/24` | Internet Gateway - load balancers and NAT only |
| Application (private) | `10.x.11.0/24`, `10.x.12.0/24` | Outbound only, through NAT Gateway |
| Database (private) | `10.x.21.0/24`, `10.x.22.0/24` | None |

`x` is 20 for dev, 30 for staging, 40 for prod, so the environments can be
peered later without CIDR collisions.

## Why two deployment models

The assessment asks for both. They are not redundant - they answer different
constraints:

* **ECS Fargate (containerised)** - no servers to patch, per-task IAM, fast
  rollback by task definition revision, scales in seconds. This is the model
  recommended for the workload.
* **EC2 + CodeDeploy (non-containerised)** - the application runs as two
  `systemd` units on Amazon Linux 2023. Useful when the workload needs host
  access, a licensed agent, or when the organisation is not yet on containers.
  CodeDeploy gives one-at-a-time rolling releases with health validation.

Both read the same database and the same secret, and both are described in the
same CloudFormation stack family.
