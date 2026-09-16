## Deployments Structure
Each subfolder in the `deployments/` directory is a Helm chart containing:
- `Chart.yaml`: Metadata about the chart
- `values.yaml`: Default configuration values
- `templates/`: Directory containing Kubernetes manifests (YAML files)