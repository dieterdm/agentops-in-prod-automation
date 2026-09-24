# AgentOps in Production - Automation

GitOps automation for deploying the **AgentOps in Production: Agentic End-to-End Observability with Red Hat AI** workshop infrastructure on OpenShift using Helm and ArgoCD.

## Related Repositories

| Repository | Description |
|------------|-------------|
| [agentops-in-prod-showroom](https://github.com/rhpds/agentops-in-prod-showroom) | Workshop content and lab instructions (Showroom) |
| [multi-agent-loan-origination](https://github.com/rh-ai-quickstart/multi-agent-loan-origination) | Multi-agent mortgage lending application deployed by this automation |

## Architecture

This repo implements an **app-of-apps** pattern: a single bootstrap Helm chart generates ArgoCD Applications that deploy the full stack per user.

```
bootstrap/                         # ArgoCD app-of-apps parent chart
├── values.yaml                    # User count, cluster domain, repo URL
└── templates/
    ├── mlflow.yaml                # MLflow tracking server
    ├── openshift-ai-operator.yaml # RHOAI operator
    ├── openshift-ai.yaml          # RHOAI instance
    ├── cluster-monitoring.yaml    # User workload monitoring
    ├── logging.yaml               # Cluster logging

deployments/                       # Individual Helm charts
├── mortgage-ai/                   # Full mortgage-ai stack (API, UI, DB, Keycloak, MinIO, LlamaStack)
├── workspace/                     # Per-user namespace, RBAC, LLM secrets
├── grafana/                       # Grafana operator, dashboards, datasources
├── mlflow/                        # MLflow tracking server
├── minio/                         # MinIO object storage
├── dspa/                          # Data Science Pipelines Application
├── openshift-ai/                  # RHOAI DataScienceCluster
├── openshift-ai-operator/         # RHOAI operator subscription
├── cluster-monitoring/            # OpenShift monitoring config
├── logging/                       # Cluster logging stack
└── image-puller/                  # DaemonSet for pre-pulling notebook images
```
