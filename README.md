# AgentOps in Production - Automation

GitOps automation for deploying the **AgentOps in Production: Agentic End-to-End Observability with Red Hat AI** workshop infrastructure on OpenShift using Helm and ArgoCD.

## Related Repositories

| Repository | Description |
|------------|-------------|
| [agentops-in-prod-showroom](https://github.com/rhpds/agentops-in-prod-showroom) | Workshop content and lab instructions (Showroom) |
| [multi-agent-loan-origination](https://github.com/rh-ai-quickstart/multi-agent-loan-origination) | Multi-agent mortgage lending application deployed by this automation |

## Architecture

This repo implements an **app-of-apps** pattern: a single bootstrap Helm chart generates ArgoCD Applications that deploy the full stack.

```
bootstrap/                         # ArgoCD app-of-apps parent chart
├── values.yaml                    # Cluster domain, repo URL
└── templates/
    ├── mlflow.yaml                # MLflow tracking server
    ├── openshift-ai-operator.yaml # RHOAI operator
    ├── openshift-ai.yaml          # RHOAI instance
    ├── cluster-monitoring.yaml    # User workload monitoring
    ├── kuadrant.yaml              # Kuadrant API gateway policies
    ├── logging.yaml               # Cluster logging
    └── extra-resources/           # Namespaces, operators, RBAC, MCP config

deployments/                       # Individual Helm charts
├── cluster-monitoring/            # OpenShift monitoring config
├── kuadrant/                      # Kuadrant operator and gateway policies
├── logging/                       # Cluster logging stack
├── mlflow/                        # MLflow tracking server
├── openshift-ai/                  # RHOAI DataScienceCluster
└── openshift-ai-operator/         # RHOAI operator subscription
```

## Prerequisites

- Red Hat OpenShift GitOps installed on the cluster
- User `dieter` must exist on the cluster
- An S3-compatible bucket for LokiStack logging storage. You can create one using OpenShift Data Foundation:

```yaml
apiVersion: objectbucket.io/v1alpha1
kind: ObjectBucketClaim
metadata:
  name: rhoai-logging
  namespace: clusters-rhoai
  labels:
    app: noobaa
    bucket-provisioner: openshift-storage.noobaa.io-obc
    noobaa-domain: openshift-storage.noobaa.io
spec:
  additionalConfig:
    bucketclass: noobaa-default-bucket-class
  generateBucketName: rhoai-logging
  objectBucketName: obc-clusters-rhoai-rhoai-logging
  storageClassName: openshift-storage.noobaa.io
```

## Configuration

Sensitive values (S3 credentials) are kept in a separate file that is not checked into git. Copy the example and fill in your values:

```bash
cp bootstrap/values.secret.yaml.example bootstrap/values.secret.yaml
# Edit bootstrap/values.secret.yaml with your S3 bucket credentials and other secrets
```

Update `bootstrap/values.yaml` and `deployments/openshift-ai/values.yaml` with your cluster's domain and TLS certificate name:

```bash
CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
echo $CLUSTER_DOMAIN

CERT_NAME=$(kubectl get ingresscontroller default -n openshift-ingress-operator -o jsonpath='{.spec.defaultCertificate.name}' 2>/dev/null)
echo $CERT_NAME
```

### Storage class

LokiStack provisions its PVCs with the storage class set in `logging.storageClassName` in `bootstrap/values.yaml` (default `kubevirt-csi-infra-default`). List the available storage classes and set it to match your cluster:

```bash
oc get storageclass
```

### External model provider (optional)

If your cluster does not have GPU access, you can configure MaaS to use an external model provider instead. Set `maas_external_provider.enabled: true` in `bootstrap/values.yaml` and provide the API key and endpoint in `bootstrap/values.secret.yaml`.

You can create an external model on the Red Hat MaaS platform at https://maas-rhdp-frontend.apps.maas.redhatworkshops.io/

## Deployment

Deploy the bootstrap Helm chart to kick off the app-of-apps:

```bash
oc project default
helm install bootstrap ./bootstrap -f ./bootstrap/values.yaml -f ./bootstrap/values.secret.yaml
```

To apply changes after modifying values or templates:

```bash
helm upgrade bootstrap ./bootstrap -f ./bootstrap/values.yaml -f ./bootstrap/values.secret.yaml
```
