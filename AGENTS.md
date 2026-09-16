## Deployments Structure
Each subfolder in the `deployments/` directory is a Helm chart containing:
- `Chart.yaml`: Metadata about the chart
- `values.yaml`: Default configuration values
- `templates/`: Directory containing Kubernetes manifests (YAML files)

The `bootstrap/template` folder contains a YAML file for each subfolder in the `deployments/` folder. This follows an app-of-apps pattern where ArgoCD will deploy all the Helm charts in the `deployments` folder.

## Architecture
This repo implements an **app-of-apps** pattern: a single bootstrap Helm chart generates ArgoCD Applications that deploy the full stack per user.

## What Gets Deployed
Each workshop user (`user1`..`userN`) gets an isolated namespace (`wksp-userX`) with:

- **Kuadrant**: Network policies and rate limiting for the mortgage-ai application (deployed in `openshift-gitops` namespace)

## Deployment Scope
All Applications and ApplicationSets in this repository are deployed to the `openshift-gitops` namespace by default.
- **Mortgage AI application**: Multi-agent loan origination system (API + UI + PostgreSQL/pgvector + Keycloak + MinIO)
- **MLflow**: Experiment tracking and agent trace observability
- **Grafana dashboards**: LLM token usage, inference latency, agent performance metrics
- **Data Science Pipelines**: Kubeflow Pipelines for ML workflows
- **OpenShift AI**: Model serving, notebooks, and platform ML tooling

