# Jenkins Setup Notes

## Required Plugins
- Git
- Pipeline
- Docker Pipeline
- SonarQube Scanner for Jenkins
- Kubernetes CLI Plugin
- AWS Credentials / Pipeline: AWS Steps

## Global Configuration
1. **Manage Jenkins → Tools**: add a Maven installation (`Maven-3.9`) and JDK (`JDK-17`)
   matching the names referenced in the `Jenkinsfile`'s `tools {}` block.
2. **Manage Jenkins → System → SonarQube servers**: add a server named `SonarQubeServer`
   with its URL and an authentication token credential.
3. **Credentials**:
   - `aws-credentials` (or an attached IAM instance role) for ECR/EKS access
   - Git credentials for repository checkout (SSH key or PAT)
4. **Webhook**: configure your Git provider to POST to
   `https://<jenkins-host>/github-webhook/` (or the GitLab equivalent) on push.

## Multibranch / Parameterized Job
Create a Pipeline job pointing at this repo's `Jenkinsfile`. The `ENVIRONMENT` parameter
(`dev` / `staging` / `prod`) selects which Helm values file and Kubernetes namespace to deploy to.

## Troubleshooting Checklist
- `kubectl get pods -n <namespace>` — check pod status
- `kubectl describe pod <pod> -n <namespace>` — check events (image pull errors, resource limits)
- `kubectl logs <pod> -n <namespace>` — application-level errors
- `helm history app-release -n <namespace>` — review past releases
- `helm rollback app-release <revision> -n <namespace>` — roll back a bad deploy
