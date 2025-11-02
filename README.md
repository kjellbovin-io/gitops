# Install Guide — RKE2 + MetalLB + Argo CD  
*(Vendored Helm charts + App-of-Apps)*

This repo installs a single-node **RKE2** Kubernetes control plane and deploys **MetalLB** and **Argo CD** using **vendored Helm charts** (air-gapped friendly). It also uses the **app-of-apps** pattern so Argo CD can manage **MetalLB** and **itself** from Git.

---

## Repo structure (at repo root)

```
.
├── vendor-versions.env                 # Pins: ARGOCD_CHART_VERSION, METALLB_CHART_VERSION, etc.
├── scripts/
│   └── vendor/                         # Modular per-app vendoring scripts
│       ├── _common.sh
│       ├── all.sh                      # runs all vendoring scripts
│       ├── argocd.sh                   # vendors argocd/vendor/argo-cd-<ver>/
│       ├── metallb.sh                  # vendors metallb/vendor/metallb-<ver>/
│       └── kube-state-metrics.sh       # example: vendors kube-state-metrics/vendor/... (optional)
│
├── clusters/
│   └── prod.yaml                       # Root Application (app-of-apps) -> scans ./apps/
│
├── apps/
│   ├── argocd.yaml                     # Application -> installs Argo CD from vendored chart
│   ├── metallb.yaml                    # Application (wave 0) -> installs MetalLB chart
│   └── metallb-config.yaml             # Application (wave 1) -> applies IP pool + L2Advertisement
│
├── argocd/
│   ├── values/
│   │   ├── base.yaml
│   │   └── custom-values.yaml          # your Argo CD overrides (LB IP, flags, replicas, etc.)
│   └── vendor/
│       └── argo-cd-9.0.5/              # vendored Argo CD chart (contains Chart.yaml)
│
├── metallb/
│   ├── values/
│   │   └── base.yaml
│   ├── manifests/
│   │   ├── ipaddresspool.yaml          # e.g. 192.168.68.240–192.168.68.250 (edit for your LAN)
│   │   └── l2advertisement.yaml
│   └── vendor/
│       └── metallb-0.15.2/             # vendored MetalLB chart (contains Chart.yaml)
│
└── README.md
```

> **Vendor folder note**  
> - `apps/metallb.yaml` (wave 0) installs the **MetalLB chart** from `metallb/vendor/metallb-<version>/`.  
> - `apps/metallb-config.yaml` (wave 1) applies **pool/L2 CRs** from `metallb/manifests/`.

---

## 1) Install RKE2 (Server)

```bash
sudo su
curl -sfL https://get.rke2.io | sh -
systemctl enable rke2-server.service
systemctl start rke2-server.service
exit
```

Configure `kubectl`:

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/rke2/rke2.yaml ~/.kube/config
sudo chown "$(id -u)":"$(id -g)" ~/.kube/config

export PATH=$PATH:/var/lib/rancher/rke2/bin
echo 'export PATH=$PATH:/var/lib/rancher/rke2/bin' >> ~/.bashrc

# (Optional) shell conveniences
source <(kubectl completion bash)
echo 'source <(kubectl completion bash)' >> ~/.bashrc
alias k=kubectl
complete -F __start_kubectl k
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -F __start_kubectl k' >> ~/.bashrc
```

Verify:

```bash
kubectl get nodes -o wide
kubectl -n kube-system get pods
```

---

## 2) Vendor exact chart versions (modular per-app scripts)

1) Set versions:
```bash
sed -n '1,200p' vendor-versions.env
```

2) Vendor charts (all at once):
```bash
bash scripts/vendor/all.sh
```

*(Or run a single app’s script, e.g. `bash scripts/vendor/metallb.sh`.)*

This creates:
- `argocd/vendor/argo-cd-9.0.5/`
- `metallb/vendor/metallb-0.15.2/`

Commit these if Argo CD will read from your Git remote.

---

## 3) Install MetalLB (chart + your address pool)

**Edit** `metallb/manifests/ipaddresspool.yaml` for your LAN (same L2 as the node; avoid DHCP). Then install MetalLB:

```bash
helm upgrade --install metallb   ./metallb/vendor/metallb-0.15.2   --namespace metallb-system --create-namespace   -f ./metallb/values/base.yaml
```

Apply the pool & L2Advertisement:

```bash
kubectl -n metallb-system apply -f ./metallb/manifests/ipaddresspool.yaml
kubectl -n metallb-system apply -f ./metallb/manifests/l2advertisement.yaml
```

Verify:

```bash
kubectl -n metallb-system get pods
kubectl -n metallb-system get ipaddresspools.metallb.io
kubectl -n metallb-system get l2advertisements.metallb.io
```

---

## 4) Install Argo CD (chart) with a fixed MetalLB IP

Put your overrides in `argocd/values/custom-values.yaml` (e.g., `service.type: LoadBalancer`, `loadBalancerIP`, `--insecure`, replicas, etc.), then:

```bash
helm upgrade --install argocd   ./argocd/vendor/argo-cd-9.0.5   --namespace argocd --create-namespace   -f ./argocd/values/base.yaml   -f ./argocd/values/custom-values.yaml
```

Check and get password:

```bash
kubectl -n argocd get pods
kubectl -n argocd get svc argocd-server -o wide
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

---

## 5) App-of-Apps (GitOps)

- The **root app** is `clusters/prod.yaml` and points to the `apps/` folder.  
- The **child apps** live in `apps/`:
  - `apps/argocd.yaml` → installs/updates Argo CD from `argocd/vendor/argo-cd-9.0.5` with your values.
  - `apps/metallb.yaml` (wave 0) → installs MetalLB chart from `metallb/vendor/metallb-0.15.2`.
  - `apps/metallb-config.yaml` (wave 1) → applies IP pool & L2Advertisement from `metallb/manifests`.

Apply and check:

```bash
kubectl apply -f clusters/prod.yaml
kubectl -n argocd get app -o wide
```

---

## 6) Add a new app (vendored Helm chart)

Create the app **at repo root** (same level as `argocd/`, `metallb/`, `apps/`) and put its `Application` under `apps/`.

### 6.1 Pin version
Add to `vendor-versions.env` (example):
```env
KUBE_STATE_METRICS_CHART_VERSION=5.15.3
```

### 6.2 Vendor via per-app script (preferred)
Use the ready script:
```
scripts/vendor/kube-state-metrics.sh
```
or add your own by following the pattern in `scripts/vendor/argocd.sh` / `metallb.sh` and `_common.sh`, then run:
```bash
bash scripts/vendor/kube-state-metrics.sh
```

This creates:
```
kube-state-metrics/vendor/kube-state-metrics-5.15.3/
```

### 6.3 Create values
```bash
mkdir -p kube-state-metrics/values

cat > kube-state-metrics/values/base.yaml <<'YAML'
prometheusScrape: false
YAML

cat > kube-state-metrics/values/custom-values.yaml <<'YAML'
replicas: 1
YAML
```

### 6.4 Add the `Application` under `apps/`
```yaml
# apps/kube-state-metrics.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kube-state-metrics
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "10"
spec:
  project: default
  source:
    repoURL: https://github.com/<you>/gitops.git
    targetRevision: main
    path: kube-state-metrics/vendor/kube-state-metrics-5.15.3
    helm:
      valueFiles:
        - ../../values/base.yaml
        - ../../values/custom-values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: kube-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 6.5 Commit & push; the root app picks it up
```bash
git add apps/kube-state-metrics.yaml kube-state-metrics vendor-versions.env scripts/vendor/
git commit -m "add kube-state-metrics (vendored) via app-of-apps"
git push

kubectl -n argocd get app
```

---

## Troubleshooting

- **Root app reads Helm templates** → Ensure `clusters/prod.yaml` points to `path: apps` so it doesn’t recurse into `vendor/`.  
- **`ComparisonError: app path does not exist`** → The *remote* repo/branch is missing that path. Push your files. Child apps should reference the **versioned** vendor folders.  
- **Apps show `Unknown`** → Confirm **application-controller** is running:
  ```bash
  kubectl -n argocd get deploy,pods
  ```
- **No External IP** → Validate MetalLB pods and that your `IPAddressPool` range is correct and free.

---

## Summary

- **RKE2** cluster up  
- **MetalLB** provides LoadBalancer IPs  
- **Argo CD** installed from vendored chart and **self-managed** via app-of-apps  
- Clear, modular pattern to **vendor** and **add new apps** reproducibly
