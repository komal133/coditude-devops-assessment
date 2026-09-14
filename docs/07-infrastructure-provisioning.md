# 7. Infrastructure provisioning approach

## Tooling decision

AWS CloudFormation, native YAML, no wrapper framework (no CDK, no Terraform,
no SAM). Reasons: the assessment specifies CloudFormation; it is the only IaC
tool with no state file to lose or lock; drift detection, change sets and
automatic rollback are built in; and a reviewer can read the YAML without
installing anything.

## Structure: layered stacks, not one template

```
00-github-oidc        CI identity          (account-scoped, deployed once)
10-network            VPC, subnets, SGs    (changes rarely)
20-database           RDS + secret         (stateful, longest-lived)
30-platform           ECR, ALB, cluster    (changes occasionally)
40-ecs-services       Fargate workloads    (changes with sizing)
50-ec2-noncontainer   EC2 workloads        (changes with sizing)
60-monitoring         alarms, dashboard    (changes freely)
70-aws-native-pipeline  CodePipeline       (optional)
```

The split follows **rate of change and blast radius**. A monolithic template
would mean that editing an alarm threshold puts the VPC and the database into
the same change set. Here, a monitoring change can only affect monitoring.

Layers communicate through CloudFormation **Outputs/Exports** consumed with
`Fn::ImportValue`. This is deliberate: AWS refuses to delete or modify an
export that another stack imports, so the dependency graph is enforced by the
platform rather than by documentation.

Security group rules are declared as standalone
`AWS::EC2::SecurityGroupIngress` resources instead of inline `ingress` blocks.
Inline rules that reference each other across stacks create circular
dependencies; standalone rules do not.

## Reusability

* **One template per layer, used by every environment.** There is no
  `prod-network.yaml`. The same `10-network.yaml` builds dev, staging and prod.
* **Parameters carry the differences**, not copies of the code:
  `infrastructure/params/{dev,staging,prod}.env`.
* **`deploy.sh` makes one parameter file serve every template.** It calls
  `aws cloudformation get-template-summary` to ask which parameters a given
  template declares, then passes only those. Adding a parameter to a template
  requires no change to the script and no new file.
* **Conditions handle structural differences**, for example
  `HighAvailabilityNat` creating a second NAT Gateway only in prod, and
  HTTPS activation is domain/certificate dependent and was not enabled because no controlled domain or ACM certificate was available for this assessment environment. The v1.1 guide documents the optional ACM certificate and HTTPS listener configuration.
* **`reusable-ec2-deploy.yml`** applies the same principle to CI: one workflow
  definition, called three times with a different environment input.

## Environment management

| Concern | dev | staging | prod |
|---|---|---|---|
| Stack names | `dev-*` | `staging-*` | `prod-*` |
| Export namespace | `dev-VpcId` ... | `staging-VpcId` ... | `prod-VpcId` ... |
| VPC CIDR | 10.20.0.0/16 | 10.30.0.0/16 | 10.40.0.0/16 |
| Approval to deploy | none | required reviewer | required reviewer |
| Resilience | single NAT, single-AZ RDS | single NAT, single-AZ RDS | NAT per AZ, Multi-AZ RDS, deletion protection |

Environments are separated by naming convention inside one account, which
keeps the assessment cheap to run. In a real organisation each environment
would be a separate AWS account under AWS Organizations, with the same
templates and the same parameter files unchanged â€” that is the point of
keeping differences in data rather than code.

## Provisioning lifecycle

1. **Author** â€” edit a template or a parameter file on a branch.
2. **Validate** â€” `cfn-lint infrastructure/*.yaml` runs in CI before anything
   reaches AWS, and can be run locally with the same command.
3. **Preview (optional, recommended for prod)** â€”
   `aws cloudformation deploy --no-execute-changeset ...` produces a change set
   that lists exactly which resources would be modified, replaced or deleted.
4. **Apply** â€” merge to `main`. The `Infrastructure` workflow deploys dev
   automatically, then waits for approval before staging and prod.
5. **Verify** â€” the deploy script prints the stack outputs; alarms and the
   dashboard confirm runtime health.
6. **Roll back** â€” failed updates roll back automatically; see `06-rollback.md`.

## Handling state and drift

* RDS carries `DeletionPolicy: Snapshot` and `UpdateReplacePolicy: Snapshot`,
  so no template mistake can destroy data without leaving a snapshot.
* The S3 artifact bucket carries `DeletionPolicy: Retain`.
* Check for manual console changes with:

  ```bash
  aws cloudformation detect-stack-drift --stack-name dev-network
  aws cloudformation describe-stack-resource-drifts --stack-name dev-network \
    --stack-resource-drift-status-filters MODIFIED DELETED
  ```

* Application releases are intentionally **outside** CloudFormation (new ECS
  task definition revisions, new S3 object versions), so routine deployments
  can never cause drift in the stacks.