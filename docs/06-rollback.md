# 6. Rollback strategy

Every layer has an answer, and most of them are automatic.

## 1. Infrastructure (CloudFormation)

* A failed stack update rolls back automatically to the last known good state.
* `Snapshot` deletion policy on RDS means a mistaken database replacement still
  leaves a snapshot behind.
* To inspect before applying, use a change set instead of `deploy`:
  ```bash
  aws cloudformation deploy --no-execute-changeset ...   # prints the change set name
  aws cloudformation describe-change-set --change-set-name <name> --stack-name prod-platform
  ```
* To abort an update that is still running:
  ```bash
  aws cloudformation cancel-update-stack --stack-name prod-platform
  ```

## 2. Containerised application (ECS)

* **Automatic**: the deployment circuit breaker is enabled with
  `Rollback: true`. If the new tasks fail to reach a steady state, ECS puts the
  previous task definition back without anyone intervening.
* **Manual**: run the `Rollback` workflow from the Actions tab, or:
  ```bash
  aws ecs update-service --cluster prod-cluster --service prod-backend \
    --task-definition prod-backend:41
  aws ecs wait services-stable --cluster prod-cluster --services prod-backend
  ```
  Task definition revisions are immutable, so revision 41 is byte-identical to
  what was running before revision 42.

## 3. Non-containerised application (CodeDeploy)

* **Automatic**: `AutoRollbackConfiguration` is enabled on
  `DEPLOYMENT_FAILURE`. `scripts/validate.sh` fails the deployment if
  `/api/health` or `/health` does not answer, which triggers the rollback to
  the last successful revision.
* **Manual**: redeploy any earlier bundle - the S3 bucket is versioned:
  ```bash
  aws deploy create-deployment --application-name prod-app \
    --deployment-group-name prod-app-dg \
    --s3-location bucket=prod-app-artifacts-<acct>-ap-south-1,key=releases/app-<oldsha>.zip,bundleType=zip
  ```
* **Stop in flight**:
  ```bash
  aws deploy stop-deployment --deployment-id d-XXXXXXXX --auto-rollback-enabled
  ```

## 4. Database

* Automated backups with point-in-time recovery (1 day in dev, 14 in prod).
* Restore creates a *new* instance; repoint the application by updating the
  secret's host value and restarting the services.
* Schema changes should be backward compatible (expand-then-contract) so that
  an application rollback never needs a database rollback.

## Decision guide

| Symptom | Action |
|---|---|
| New release returns 5xx | ECS circuit breaker or CodeDeploy rolls back automatically; confirm in CloudWatch |
| Release is "healthy" but wrong behaviour | Run the `Rollback` workflow with the previous revision |
| Infrastructure change broke networking | CloudFormation auto-rollback; if the stack is stuck, `cancel-update-stack` |
| Data corrupted by a bad migration | RDS point-in-time restore, then repoint the secret |
