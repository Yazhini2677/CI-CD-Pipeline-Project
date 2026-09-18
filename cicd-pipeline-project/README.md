# End-to-End CI/CD Pipeline for Containerized Application

**Stack:** AWS | Jenkins | Git | Maven | SonarQube | Docker | Kubernetes | Helm

## Overview

This project implements a fully automated CI/CD pipeline that takes a Java (Spring Boot) application
from source commit to a running pod in Kubernetes, with quality gates enforced along the way.

**Pipeline flow:**

```
Git Push --> Jenkins Trigger --> Maven Build & Unit Tests --> SonarQube Analysis
   --> Quality Gate --> Docker Build & Push (ECR) --> Helm Deploy --> Kubernetes (EKS)
```

## Architecture

- **Source Control:** Git (GitHub/GitLab), webhook-triggered Jenkins builds
- **CI Orchestrator:** Jenkins (declarative pipeline, `Jenkinsfile` in repo root)
- **Build Tool:** Maven (`pom.xml`) — compiles, runs unit tests, packages a JAR
- **Code Quality:** SonarQube static analysis with a quality gate that fails the
  pipeline if coverage/bugs/vulnerabilities thresholds aren't met
- **Containerization:** Docker multi-stage build, image pushed to Amazon ECR
- **Orchestration:** Kubernetes (Amazon EKS)
- **Release Management:** Helm chart templating Deployment/Service/Ingress/HPA
- **Cloud Provider:** AWS (EKS, ECR, IAM, ALB Ingress Controller)

## Repository Structure

```
cicd-pipeline-project/
├── Jenkinsfile                     # Declarative pipeline definition
├── Dockerfile                      # Multi-stage image build
├── sonar-project.properties        # SonarQube scanner config
├── app/                            # Sample Spring Boot application
│   ├── pom.xml
│   └── src/
│       ├── main/java/com/example/app/...
│       └── test/java/com/example/app/...
├── k8s/                             # Raw Kubernetes manifests (reference / non-Helm envs)
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── hpa.yaml
├── helm/
│   └── app-chart/                   # Helm chart used by the pipeline
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── ingress.yaml
│           ├── hpa.yaml
│           └── _helpers.tpl
└── jenkins/
    └── README.md                    # Jenkins agent/plugin setup notes
```

## Responsibilities Covered

- Jenkins pipeline configuration (declarative, multi-stage, parameterized)
- Git integration (webhooks, branch strategy, credentials management)
- Maven build lifecycle (compile, test, package)
- SonarQube static analysis + quality gate enforcement
- Docker image build, tag (by commit SHA + build number), and push to ECR
- Kubernetes deployment manifests (Deployment, Service, Ingress, HPA)
- Helm chart authoring and parameterized deployments across environments (dev/staging/prod)
- Rollback strategy and deployment troubleshooting (`helm rollback`, `kubectl describe/logs`)

## Prerequisites

- Jenkins server with plugins: Git, Pipeline, Docker Pipeline, SonarQube Scanner,
  Kubernetes CLI, AWS Credentials
- AWS account with an EKS cluster, ECR repository, and IAM role for Jenkins
  (or an IAM user with ECR push + EKS deploy permissions)
- SonarQube server reachable from Jenkins, with a project token generated
- `kubectl` and `helm` (v3) installed on the Jenkins agent
- Docker installed on the Jenkins agent (or a Docker-in-Docker agent)

## How the Pipeline Works (stage by stage)

1. **Checkout** — Jenkins pulls the branch that triggered the build via the configured webhook.
2. **Build & Unit Test** — `mvn clean verify` compiles the app and runs unit tests; test
   reports are published in Jenkins.
3. **SonarQube Analysis** — `mvn sonar:sonar` sends analysis to SonarQube; the pipeline
   then waits on the SonarQube webhook for the Quality Gate result and fails fast if it doesn't pass.
4. **Docker Build & Push** — builds a multi-stage image tagged `<ECR_REPO>:<git-sha>` and
   `:latest`, authenticates to ECR via `aws ecr get-login-password`, and pushes both tags.
5. **Helm Deploy** — `helm upgrade --install` applies the chart to the target namespace,
   injecting the new image tag as a value, with `--atomic` so a bad rollout auto-rolls back.
6. **Post-deploy verification** — `kubectl rollout status` confirms the deployment is healthy;
   on failure, Jenkins captures pod logs/events for troubleshooting before marking the build failed.

## Environments

The Helm chart is parameterized via per-environment values files
(`values-dev.yaml`, `values-staging.yaml`, `values-prod.yaml` — add as needed) so the same
chart promotes through environments with only image tag and resource/replica differences.

## Rollback

```bash
helm history app-release -n <namespace>
helm rollback app-release <revision> -n <namespace>
```

## Getting Started Locally

```bash
cd app
mvn clean package
docker build -t app:local .
docker run -p 8080:8080 app:local
```
