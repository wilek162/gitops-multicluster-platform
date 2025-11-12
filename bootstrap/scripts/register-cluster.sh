#!/usr/bin/env bash
# Register a cluster with ArgoCD by creating a Secret with the cluster's kubeconfig
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

KUBECONFIG_PATH=${1:-"${REPO_ROOT}/bootstrap/gitops.kubeconfig"}
ARGOCD_SERVER=${2:-https://localhost:8080}
CLUSTER_NAME=${3:-demo-cluster}
KUBE_CONTEXT=${4:-}

echo "Registering cluster '${CLUSTER_NAME}' with ArgoCD at ${ARGOCD_SERVER}"
echo "Using kubeconfig: ${KUBECONFIG_PATH}"

if ! command -v argocd &>/dev/null; then
    echo "❌ argocd CLI not found. Install: https://argo-cd.readthedocs.io/en/stable/cli_installation/"
    exit 1
fi

if [ ! -f "${KUBECONFIG_PATH}" ]; then
    echo "❌ kubeconfig not found at ${KUBECONFIG_PATH}"
    exit 1
fi

# Determine context name if not provided
if [ -z "$KUBE_CONTEXT" ]; then
    KUBE_CONTEXT=$(kubectl --kubeconfig="${KUBECONFIG_PATH}" config view -o jsonpath='{.contexts[0].name}')
    echo "Auto-detected kube-context: ${KUBE_CONTEXT}"
fi

echo "Make sure ArgoCD server is reachable and you are logged in (e.g. kubectl port-forward svc/argocd-server -n argocd 8080:443 & and argocd login ...)."

# Add the cluster non-interactively specifying kube-context
argocd cluster add --name "${CLUSTER_NAME}" --kubeconfig "${KUBECONFIG_PATH}" --kube-context "${KUBE_CONTEXT}" --insecure

echo "✅ Cluster '${CLUSTER_NAME}' registered with ArgoCD."