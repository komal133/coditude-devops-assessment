# 2. AWS services used and why

| Area | Service | Why this one |
|---|---|---|
| Networking | VPC, subnets, Internet Gateway, NAT Gateway | Standard three-tier isolation; NAT keeps private workloads patchable without exposing them |
| Networking | Application Load Balancer | Layer-7 path routing (`/api/*`), health checks, TLS termination point |
| Compute (containers) | ECS on Fargate | No EC2 fleet to manage, task-level IAM, native deployment circuit breaker |
| Compute (containers) | Amazon ECR | Private registry, scan-on-push, lifecycle policy caps storage cost |
| Compute (servers) | EC2 Auto Scaling Group, Amazon Linux 2023 | The non-containerised requirement; ASG gives self-healing and rolling capacity |
| Deployment | AWS CodeDeploy | In-place rolling releases to the ASG with lifecycle hooks and automatic rollback |
| Database | Amazon RDS for PostgreSQL | Managed backups, encryption, Multi-AZ failover in prod, Performance Insights |
| Secrets | AWS Secrets Manager | Generated password, never in Git, rotatable, injected by ECS or fetched by IAM role |
| Identity | IAM roles, GitHub OIDC provider | Short-lived credentials for CI, least-privilege runtime roles |
| Monitoring | CloudWatch Logs, metrics, alarms, dashboard, Container Insights | One pane of glass for both deployment styles |
| Alerting | Amazon SNS | Email notification on alarm |
| CI/CD (AWS native) | CodePipeline, CodeBuild | Demonstrates the AWS-native path next to GitHub Actions |
| Artifacts | Amazon S3 (versioned) | Release bundles for CodeDeploy; versioning enables rollback to any past bundle |
| Access | AWS Systems Manager Session Manager | Shell access to instances without SSH keys or open port 22 |

## Cost notes (ap-south-1, rough)

Dev sized as in `params/dev.env` runs at roughly USD 90-120 per month, most of
it the two load balancers, the NAT Gateway and the RDS instance. Set
`HighAvailabilityNat=false` and `MultiAz=false` for dev and staging; delete the
`50-ec2-noncontainer` stack when the non-containerised demo is not needed.
