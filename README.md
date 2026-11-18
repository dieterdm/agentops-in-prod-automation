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
├── values.yaml                    # Cluster domain, repo URL, admin users
└── templates/
    ├── mlflow.yaml                # MLflow tracking server
    ├── openshift-ai-operator.yaml # RHOAI operator
    ├── openshift-ai.yaml          # RHOAI instance
    ├── cluster-monitoring.yaml    # User workload monitoring
    ├── kuadrant.yaml              # Kuadrant API gateway policies
    ├── logging.yaml               # Cluster logging
    ├── users.yaml                 # Cluster administrators
    ├── mcp-server.yaml            # OpenShift MCP server
    ├── ogx.yaml                   # OGX server for RAG (optional)
    ├── evalhub.yaml               # TrustyAI EvalHub for model evaluation (optional)
    ├── auto.yaml                  # AutoML and AutoRAG project and pipeline server (optional)
    ├── s4.yaml                    # S4 S3-compatible storage for the LokiStack bucket
    ├── seaweedfs.yaml             # SeaweedFS S3-compatible storage for the pipeline bucket
    └── extra-resources/           # Namespaces, operators, RBAC

deployments/                       # Individual Helm charts
├── auto/                          # Pipeline server for AutoML and AutoRAG
├── cluster-monitoring/            # OpenShift monitoring config
├── evalhub/                       # TrustyAI EvalHub and its PostgreSQL database
├── kuadrant/                      # Kuadrant operator and gateway policies
├── logging/                       # Cluster logging stack
├── mcp-server/                    # OpenShift MCP server and catalog entry
├── ogx/                           # OGX server, pgvector and e5 embedding model
├── mlflow/                        # MLflow tracking server
├── openshift-ai/                  # RHOAI DataScienceCluster
├── openshift-ai-operator/         # RHOAI operator subscription
├── s4/                            # S4 storage and bucket creation
├── seaweedfs/                     # SeaweedFS storage and bucket creation
└── users/                         # Admin groups and RBAC
```

## Prerequisites

- Red Hat OpenShift GitOps installed on the cluster
- Every user listed in `users.clusterAdmins` must already exist on the cluster (defaults to `dieter`). See [Cluster administrators](#cluster-administrators).

S3 storage doesn't need to be provisioned up front. Two in-cluster S3-compatible storage servers create every bucket used in this project: [S4](https://github.com/rh-aiservices-bu/s4) serves the LokiStack bucket and [SeaweedFS](https://github.com/seaweedfs/seaweedfs) serves the AutoML/AutoRAG pipeline bucket. Apps that use a bucket wait until their storage server is up and the bucket exists.

## Configuration

Sensitive values (S4 and SeaweedFS credentials, API keys) are kept in a separate file that is not checked into git. Copy the example and fill in your values:

```bash
cp bootstrap/values.secret.yaml.example bootstrap/values.secret.yaml
# Edit bootstrap/values.secret.yaml with your S4 and SeaweedFS credentials and other secrets
```

Update `bootstrap/values.yaml` and `deployments/openshift-ai/values.yaml` with your cluster's domain and TLS certificate name:

```bash
CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
echo $CLUSTER_DOMAIN

CERT_NAME=$(kubectl get ingresscontroller default -n openshift-ingress-operator -o jsonpath='{.spec.defaultCertificate.name}' 2>/dev/null)
echo $CERT_NAME
```

### Cluster administrators

The `users` chart grants administrative access to the users listed in `users.clusterAdmins` in `bootstrap/values.yaml`:

```yaml
users:
  clusterAdmins:
    - dieter
```

Each listed user is added to the `cluster-admins` and `rhods-admins` groups, bound to the `cluster-admin` ClusterRole, and given the `role:admin` policy in OpenShift GitOps. The users are not created by this chart, so they must already exist on the cluster.

#### Hosted control plane (HCP) clusters on OpenShift Virtualization

On a hosted cluster, the user must be created through the `HostedCluster` resource on the infra (hosting) cluster. Replace `<username>` with the user to create and `<cluster-name>` with the name of the hosted cluster.

1. Create an htpasswd file:

   ```bash
   htpasswd -c -B ./htpasswd-file <username>
   ```

2. Create the secret in the `clusters` namespace on the infra cluster:

   ```bash
   oc create secret generic htpasswd-secret --from-file=htpasswd=./htpasswd-file -n clusters
   ```

3. **Important:** adding an identity provider removes the `kubeadmin` login on the hosted cluster. Before patching, log in to the hosted cluster as `kubeadmin` and give the user cluster-admin rights:

   ```bash
   oc adm policy add-cluster-role-to-user cluster-admin <username>
   ```

4. Patch the hosted cluster on the infra cluster to add the htpasswd identity provider:

   ```bash
   oc patch hostedcluster <cluster-name> -n clusters --type=merge --patch='{
     "spec": {
       "configuration": {
         "oauth": {
           "identityProviders": [
             {
               "name": "htpasswd-provider",
               "mappingMethod": "claim",
               "type": "HTPasswd",
               "htpasswd": {
                 "fileData": {
                   "name": "htpasswd-secret"
                 }
               }
             }
           ]
         }
       }
     }
   }'
   ```

### Storage class

LokiStack provisions its PVCs with the storage class set in `logging.storageClassName` in `bootstrap/values.yaml` (default `kubevirt-csi-infra-default`). List the available storage classes and set it to match your cluster:

```bash
oc get storageclass
```

### External model provider (optional)

If your cluster does not have GPU access, you can configure MaaS to use an external model provider instead. Set `maas_external_provider.enabled: true` in `bootstrap/values.yaml` and provide the API key and endpoint in `bootstrap/values.secret.yaml`.

You can create an external model on the Red Hat MaaS platform at https://maas-rhdp-frontend.apps.maas.redhatworkshops.io/

### OGX RAG server (optional)

The `ogx` chart deploys an OGX server with a pgvector database and the `multilingual-e5-large` embedding model in the `ogx` namespace. It is enabled by default. To skip it, set `ogx.enabled: false` in `bootstrap/values.yaml`; the `rag` section in `bootstrap/values.secret.yaml` is then not needed.

When enabled, set the LLM and embedding endpoints in the `rag` section of `bootstrap/values.secret.yaml` (see `bootstrap/values.secret.yaml.example`).

### EvalHub (optional)

The `evalhub` chart deploys TrustyAI EvalHub with a PostgreSQL database in the `evalhub` namespace, for running evaluations such as `lm-evaluation-harness`, `garak` and `guidellm` against models. It is enabled by default. To skip it, set `evalhub.enabled: false` in `bootstrap/values.yaml`.

The providers, benchmark collections, MLflow tracking URI and database settings are in `deployments/evalhub/values.yaml`. EvalHub runs single-tenant: it serves only the `evalhub` namespace, where evaluation jobs run.

### S4 storage

The `s4` chart is always deployed. It runs [S4](https://github.com/rh-aiservices-bu/s4) in the `s4` namespace with a 50Gi volume and creates the LokiStack bucket (`logging.bucket` in `bootstrap/values.yaml`). The S3 API is only reachable inside the cluster, at `http://s4.s4.svc.cluster.local:7480`.

S4 also has a web console for browsing buckets and uploading or downloading files. To open it, get the URL of its route:

```bash
echo https://$(oc get route s4 -n s4 -o jsonpath='{.spec.host}')
```

Log in with the `ui_username` and `ui_password` from the `s4` section of `bootstrap/values.secret.yaml`. The same section holds the S3 access key (`access_key_id`) and secret key (`access_key_secret`) for S3 clients. All four values are also stored in the `s4-credentials` secret in the `s4` namespace:

```bash
oc extract secret/s4-credentials -n s4 --to=-
```

### SeaweedFS storage

The `seaweedfs` chart is always deployed. It runs [SeaweedFS](https://github.com/seaweedfs/seaweedfs) as a single pod on a single 50Gi volume in the `seaweedfs` namespace: the master, volume server, filer and S3 gateway run in one process, and object data and metadata share the volume. It creates the AutoML/AutoRAG pipeline bucket (`auto.bucket` in `bootstrap/values.yaml`) when `auto.enabled` is true. The S3 API is only reachable inside the cluster, at `http://seaweedfs.seaweedfs.svc.cluster.local:8333`.

The pipeline bucket moved from S4 to SeaweedFS because S4 can't store multipart uploads with long object keys: AutoML model files have keys of about 240 characters, and S4 fails those uploads with HTTP 500.

The S3 access key (`access_key_id`) and secret key (`access_key_secret`) are in the `seaweedfs` section of `bootstrap/values.secret.yaml`, and in the `seaweedfs-s3-config` secret in the `seaweedfs` namespace.

### AutoML and AutoRAG (optional)

AutoML and AutoRAG are OpenShift AI dashboard features that run automated experiments as pipelines:

- **AutoML** trains and compares several machine learning models on a tabular dataset and ranks them, so you can pick the best one to deploy.
- **AutoRAG** tries out different retrieval-augmented generation (RAG) configurations (for example chunking, embedding and retrieval settings) on your documents and ranks them on answer quality.

The `auto` chart turns both features on in the dashboard and creates an `auto` data science project to run them in. The project has a pipeline server (`DataSciencePipelinesApplication`) that stores its artifacts in the `auto-pipelines` bucket in SeaweedFS. The project also gets an `auto-pipelines` S3 connection to that bucket, which you can select in AutoML and AutoRAG to upload your data. It is enabled by default. To skip it, set `auto.enabled: false` in `bootstrap/values.yaml`; AutoML and AutoRAG are then hidden in the dashboard.

To try them out, open the `auto` project in the OpenShift AI dashboard. Sample data and example notebooks are available in the [red-hat-ai-examples](https://github.com/red-hat-data-services/red-hat-ai-examples/tree/main/examples) repository.

## Known issues

### MaaS models missing from the gen AI playground (RHOAI 3.6 EA2)

Tracked in [RHAI-49413](https://redhat.atlassian.net/browse/RHAI-49413).

MaaS models such as `gpt-oss-20b` didn't show up in the gen AI playground. We traced this to a CA trust mismatch. The cluster uses a custom default ingress certificate, signed by the cluster's self-signed root CA (`OU=openshift, CN=root-ca`). The playground's OGX server trusts the certificates in the `ogx-router-ca-bundle` ConfigMap, but the OGX operator puts only the router CA in that bundle. The router CA didn't sign the certificate served by the dashboard route, so OGX couldn't verify it.

Adding the root CA from `models-as-a-service/kube-root-ca.crt` to `ogx-router-ca-bundle` and restarting the OGX deployment made the model appear in the playground.

The `openshift-ai` chart automates this with a temporary workaround, [playground-ca-bundle-workaround.yaml](deployments/openshift-ai/templates/playground-ca-bundle-workaround.yaml). A CronJob in `models-as-a-service` checks every 5 minutes whether `ogx-router-ca-bundle` contains the root CA. If it doesn't, the CronJob adds it and restarts the playground's OGX deployment. It does nothing until a playground has been created.

The workaround is controlled by `playgroundCaBundleWorkaround` in `deployments/openshift-ai/values.yaml`. Set `enabled: false`, or remove the template and the values block, once RHAI-49413 is fixed.

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
