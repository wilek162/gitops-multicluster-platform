# 🚀 GitOps Multi-Cluster Platform

> A production-ready GitOps platform that bootstraps Kubernetes clusters with a single command, manages multi-environment deployments, and handles secrets automatically.

[![Platform](https://img.shields.io/badge/Platform-Kubernetes-blue.svg)](https://kubernetes.io/)
[![GitOps](https://img.shields.io/badge/GitOps-ArgoCD-orange.svg)](https://argoproj.github.io/cd/)

## ✨ Features

- **🎯 Single Command Bootstrap**: `./bootstrap.sh` creates everything
- **🌍 Multi-Cluster Support**: Dev, Staging, Production environments
- **🔄 GitOps Automation**: ArgoCD for declarative deployments
- **🔐 Secret Management**: Sealed Secrets support
- **📊 Monitoring Ready**: Prometheus/Grafana integration
- **🤖 PR-Based Promotions**: Automated environment promotions via `scripts/promote.sh`
- **🏠 Local Development**: KIND clusters for testing

## 🎬 Quick Demo

```bash
# Clone and bootstrap in one go
git clone <your-repo-url>
cd gitops-multicluster-platform
./bootstrap.sh

# Access ArgoCD UI (after bootstrap completes)
export KUBECONFIG="./bootstrap/demo.kubeconfig"
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Open https://localhost:8080 (username: admin)
```

## 📋 Prerequisites

- **OS**: Linux, macOS, or Windows with WSL2
- **Tools**: Docker, kubectl, kind (bootstrap will check/guide installation)
- **Optional**: Git, make

## 🚀 Installation

### Option 1: Interactive Bootstrap (Recommended)

```bash
# Run interactive bootstrap
./bootstrap.sh
```

### Option 2: Makefile Commands

```bash
make demo          # Complete demo setup
make bootstrap     # Create cluster and install ArgoCD
make sync         # Deploy applications
make port-forward # Access ArgoCD UI
make clean        # Cleanup
```

## 📁 Project Structure

```
gitops-multicluster-platform/
├── bootstrap.sh              # 🎯 Main interactive bootstrap
├── Makefile                  # Quick commands
│
├── bootstrap/                # Bootstrap scripts
│   └── scripts/
│       ├── bootstrap-kind-argocd.sh
│       └── register-cluster.sh
│
├── clusters/                 # Per-cluster configurations
│   └── dev/
│       ├── argocd-app.yaml  # ArgoCD application
│       └── apps/guestbook/  # Application manifests
│
├── apps/                     # Application catalog
│   └── guestbook/           # Demo Node.js application
│
├── scripts/                  # Helper scripts
│   └── promote.sh           # Environment promotion
│
└── tests/                    # Comprehensive test suite
    ├── test-runner.sh       # Test orchestrator
    ├── quick-smoke.sh       # Quick validation
    ├── unit/                # Unit tests
    ├── integration/         # Integration tests
    └── e2e/                 # End-to-end tests
```

## 🧪 Testing

```bash
# Run all tests
./tests/test-runner.sh --all

# Quick smoke test
./tests/test-runner.sh --quick

# Specific test types
./tests/test-runner.sh --unit
./tests/test-runner.sh --integration
```

## 🚢 Current Status

### ✅ Implemented
- Interactive bootstrap script with comprehensive configuration
- KIND cluster creation with ArgoCD
- Guestbook demo application with full Kubernetes manifests
- GitOps workflow via ArgoCD Applications
- Comprehensive test suite (unit, integration, e2e)
- Sealed Secrets support
- Environment promotion scripts

### 🚧 Planned
- Multi-environment setup (staging/prod)
- Advanced monitoring (Prometheus/Grafana)
- Cloud provider support (AWS/GCP/Azure)
- HashiCorp Vault integration

## 🔍 Troubleshooting

### ArgoCD Not Accessible

```bash
# Check ArgoCD status
kubectl get pods -n argocd

# Port forward UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### Applications Not Syncing

```bash
# Check application status
kubectl get applications -n argocd
```

---

**Made with ❤️ for the GitOps community**