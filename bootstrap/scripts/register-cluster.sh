#!/usr/bin/env bash
# Register a cluster with ArgoCD by creating a Secret with the cluster's kubeconfig
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

KUBECONFIG_PATH=${1:-"${REPO_ROOT}/bootstrap/gitops.kubeconfig"}
ARGOCD_SERVER=${2:-https://localhost:8080}
CLUSTER_NAME=${3:-demo-cluster}

echo "Registering cluster '${CLUSTER_NAME}' with ArgoCD at ${ARGOCD_SERVER}"
echo "Using kubeconfig: ${KUBECONFIG_PATH}"

# Check argocd CLI
if ! command -v argocd &>/dev/null; then
    echo "❌ argocd CLI not found. Install: https://argo-cd.readthedocs.io/en/stable/cli_installation/"
    exit 1
fi

# Check kubeconfig exists
if [ ! -f "${KUBECONFIG_PATH}" ]; then
    echo "❌ kubeconfig not found at ${KUBECONFIG_PATH}"
    echo "   If you intentionally do not have one, create it (kind create cluster ...) or provide path as first arg."
    exit 1
fi

# NOTE: argocd cluster add requires argocd CLI logged in and reachable (port-forward or network).
# The user must run: kubectl port-forward svc/argocd-server -n argocd 8080:443  & then login via argocd login.
echo "Make sure argocd server is reachable and you are logged in (e.g. port-forward and `argocd login`)."

# Try to add cluster; use --insecure if using local port-forward without TLS verification
argocd cluster add --name "${CLUSTER_NAME}" --kubeconfig "${KUBECONFIG_PATH}" --insecure

echo "✅ Cluster '${CLUSTER_NAME}' registered with ArgoCD (if login & connectivity succeeded)."
