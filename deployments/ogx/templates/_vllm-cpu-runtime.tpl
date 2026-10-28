{{/*
ServingRuntime spec for vLLM on CPU (x86) with a larger /dev/shm. vLLM needs
~160 MiB of shared memory to start its engine, but containers only get 64 MiB
by default. Shared by the dashboard Template and the ServingRuntimes deployed
from this chart.
*/}}
{{- define "ogx.vllmCpuRuntimeSpec" -}}
annotations:
  prometheus.io/path: /metrics
  prometheus.io/port: "8080"
containers:
- args:
  - --port=8080
  - --model=/mnt/models
  # Escaped so Helm leaves the KServe template variable alone.
  - --served-model-name={{ "{{.Name}}" }}
  command:
  - python
  - -m
  - vllm.entrypoints.openai.api_server
  env:
  - name: HF_HOME
    value: /tmp/hf_home
  image: registry.redhat.io/rhaii-fast/vllm-cpu-rhel9@sha256:c5af8896570f0ed54825cdf933642461ef625a760fb3fd1c8be2ec159225ea56
  name: kserve-container
  ports:
  - containerPort: 8080
    protocol: TCP
  volumeMounts:
  - name: shm
    mountPath: /dev/shm
volumes:
# Memory-backed, so it counts against the container's memory limit.
- name: shm
  emptyDir:
    medium: Memory
    sizeLimit: 1Gi
multiModel: false
supportedModelFormats:
# Dashboard deployments don't set spec.predictor.model.runtime on the
# InferenceService, so the runtime has to be auto-selectable.
- autoSelect: true
  name: vLLM
{{- end }}
