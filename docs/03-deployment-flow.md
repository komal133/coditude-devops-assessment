# 3. Deployment flow

## Stack dependency order

```
00-github-oidc        (once per AWS account)
        |
10-network            exports VPC, subnets, security groups
        |
20-database           imports subnets + DB security group
        |
30-platform           imports VPC/subnets/SGs, exports ECR, ALB, cluster, roles
        |
        +--> bootstrap container images (docker push :latest)
        |
40-ecs-services       imports everything above
50-ec2-noncontainer   imports network + secret
60-monitoring         imports ALB names + cluster
70-aws-native-pipeline (optional)
```

Stacks communicate only through CloudFormation **exports**, so a lower layer
can never be deleted while a higher layer still depends on it - CloudFormation
refuses. That is the intended safety net.

## First deployment of an environment

```bash
export AWS_REGION=ap-south-1

./infrastructure/deploy.sh dev 10-network.yaml
./infrastructure/deploy.sh dev 20-database.yaml      # ~10 minutes (RDS)
./infrastructure/deploy.sh dev 30-platform.yaml
./deploy/bootstrap-images.sh dev
./infrastructure/deploy.sh dev 40-ecs-services.yaml
./infrastructure/deploy.sh dev 50-ec2-noncontainer.yaml
./infrastructure/deploy.sh dev 60-monitoring.yaml
```

Repeat with `staging` and `prod`. Nothing else changes - the parameter file
carries the sizing differences.

## Day-2 application release

* Change a file under `apps/backend/` -> `app-backend.yml` runs -> new image,
  new task definition revision, rolling ECS update. **No CloudFormation call.**
* Change a file under `apps/frontend/` -> `app-frontend.yml` does the same.
* Any `apps/**` change also runs `app-ec2.yml`, which packages the release and
  hands it to CodeDeploy for the EC2 fleet.

## Day-2 infrastructure change

* Change a file under `infrastructure/` -> `infra.yml` runs `cfn-lint`, then
  deploys dev, then waits for approval before staging and prod.
