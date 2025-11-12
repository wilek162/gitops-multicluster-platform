#!/usr/bin/env bash
set -euo pipefail

# Quick local bootstrap using kind and argocd (demo-friendly)
CLUSTER_NAME=${1:-gitops-demo}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
KUBECONFIG_PATH="${REPO_ROOT}/bootstrap/${CLUSTER_NAME}.kubeconfig"

echo "==========================================="
echo " GitOps Platform Bootstrap"
echo "==========================================="
echo "Cluster name: $CLUSTER_NAME"
echo "Kubeconfig will be saved to: $KUBECONFIG_PATH"
echo ""

# Check if cluster already exists
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo "⚠️  Cluster '$CLUSTER_NAME' already exists!"
    read -p "Delete and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting existing cluster..."
        kind delete cluster --name "$CLUSTER_NAME"
    else
        echo "Aborting."
        exit 1
    fi
fi

echo "Creating kind cluster '$CLUSTER_NAME'..."
cat <<'KINDCONFIG' | kind create cluster --name "$CLUSTER_NAME" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30000
        hostPort: 30000
        protocol: TCP
  - role: worker
  - role: worker
KINDCONFIG

echo "✅ Kind cluster created successfully"

# Set context
kubectl cluster-info --context "kind-${CLUSTER_NAME}"

# Install ArgoCD
echo ""
echo "Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s \
    deployment/argocd-server -n argocd

echo "✅ ArgoCD installed successfully"

# Save kubeconfig
echo ""
echo "Saving kubeconfig to $KUBECONFIG_PATH..."
kind export kubeconfig --name "$CLUSTER_NAME" --kubeconfig "$KUBECONFIG_PATH"

echo "✅ Kubeconfig saved"

# Get admin password
echo ""
echo "==========================================="
echo " ArgoCD Access Information"
echo "==========================================="
echo ""
echo "🔐 ArgoCD Admin Password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d && echo
echo ""
echo "🌐 Access ArgoCD UI:"
echo "   1. Run: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   2. Open: https://localhost:8080"
echo "   3. Login with username: admin"
echo ""
echo "📝 Set kubeconfig:"
echo "   export KUBECONFIG=\"$KUBECONFIG_PATH\""
echo ""
echo "==========================================="
echo "✅ Bootstrap complete!"
echo "==========================================="
