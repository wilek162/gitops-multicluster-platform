#!/bin/bash
set -e

# GitOps Multi-Cluster Platform Bootstrap Script
# Supports: Windows (WSL2), Linux, macOS

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/.bootstrap-config"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Banner
print_banner() {
    cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║          GitOps Multi-Cluster Platform                   ║
║          Bootstrap & Management Tool                      ║
╚═══════════════════════════════════════════════════════════╝
EOF
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    # Essential tools
    command -v kubectl >/dev/null 2>&1 || missing_tools+=("kubectl")
    command -v kind >/dev/null 2>&1 || missing_tools+=("kind")
    command -v docker >/dev/null 2>&1 || missing_tools+=("docker")
    command -v git >/dev/null 2>&1 || missing_tools+=("git")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools manually or use a package manager:"
        echo "  # Ubuntu/Debian"
        echo "  sudo apt-get update && sudo apt-get install -y kubectl docker.io git"
        echo "  # Install kind: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
        echo ""
        echo "  # macOS (Homebrew)"
        echo "  brew install kubectl kind docker git"
        echo ""
        echo "  # Windows (Chocolatey)"
        echo "  choco install kubernetes-cli kind docker-desktop git"
        exit 1
    fi
    
    # Check Docker is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    log_success "All prerequisites met!"
}

# Interactive configuration
configure_platform() {
    log_info "Platform Configuration"
    echo ""
    
    # Deployment mode
    echo "Select deployment mode:"
    echo "  1) Local (KIND - Kubernetes in Docker) - Recommended for getting started"
    echo "  2) AWS (EKS) - Coming soon"
    echo "  3) GCP (GKE) - Coming soon"
    echo "  4) Azure (AKS) - Coming soon"
    read -p "Choice [1]: " DEPLOY_MODE
    DEPLOY_MODE=${DEPLOY_MODE:-1}
    
    # GitOps tool
    echo ""
    echo "Select GitOps tool:"
    echo "  1) ArgoCD (Recommended)"
    echo "  2) Flux CD (Coming soon)"
    read -p "Choice [1]: " GITOPS_TOOL
    GITOPS_TOOL=${GITOPS_TOOL:-1}
    
    # Secret management
    echo ""
    echo "Select secret management:"
    echo "  1) Native Kubernetes Secrets (Simple)"
    echo "  2) Sealed Secrets (Recommended)"
    echo "  3) HashiCorp Vault (Advanced)"
    read -p "Choice [2]: " SECRET_MGMT
    SECRET_MGMT=${SECRET_MGMT:-2}
    
    # Environments
    echo ""
    read -p "Enable multi-environment setup? (dev/staging/prod) [Y/n]: " MULTI_ENV
    MULTI_ENV=${MULTI_ENV:-Y}
    
    # Applications
    echo ""
    echo "Select demo applications to deploy:"
    echo "  1) Guestbook only"
    echo "  2) Guestbook + Monitoring"
    echo "  3) Full demo suite"
    read -p "Choice [1]: " DEMO_APPS
    DEMO_APPS=${DEMO_APPS:-1}
    
    # Git repository
    echo ""
    read -p "Git repository URL (leave empty to use current): " GIT_REPO
    if [ -z "$GIT_REPO" ]; then
        GIT_REPO=$(git config --get remote.origin.url 2>/dev/null || echo "")
    fi
    
    # Save configuration
    cat > "$CONFIG_FILE" <<EOF
DEPLOY_MODE=$DEPLOY_MODE
GITOPS_TOOL=$GITOPS_TOOL
SECRET_MGMT=$SECRET_MGMT
MULTI_ENV=$MULTI_ENV
DEMO_APPS=$DEMO_APPS
GIT_REPO=$GIT_REPO
EOF
    
    log_success "Configuration saved to $CONFIG_FILE"
}

# Load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        return 0
    fi
    return 1
}

# Bootstrap local KIND cluster
bootstrap_local() {
    log_info "Bootstrapping local KIND cluster..."
    
    # Create clusters based on configuration
    if [[ "$MULTI_ENV" =~ ^[Yy]$ ]]; then
        CLUSTERS=("dev" "staging" "prod")
    else
        CLUSTERS=("dev")
    fi
    
    for cluster in "${CLUSTERS[@]}"; do
        log_info "Creating cluster: $cluster"
        bash "${SCRIPT_DIR}/bootstrap/scripts/bootstrap-kind-argocd.sh" "$cluster"
        
        # Wait a moment between clusters to avoid resource conflicts
        if [ "$cluster" != "${CLUSTERS[-1]}" ]; then
            sleep 10
        fi
    done
    
    log_success "Local clusters created!"
}

# Install additional components
install_components() {
    local cluster=${1:-dev}
    
    log_info "Installing additional components on cluster: $cluster"
    
    # Set kubeconfig
    export KUBECONFIG="${SCRIPT_DIR}/bootstrap/${cluster}.kubeconfig"
    
    # Install secret management
    if [ "$SECRET_MGMT" == "2" ]; then
        log_info "Installing Sealed Secrets..."
        kubectl create namespace sealed-secrets-system --dry-run=client -o yaml | kubectl apply -f -
        kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.5/controller.yaml
        
        log_info "Waiting for Sealed Secrets controller..."
        kubectl wait --for=condition=ready pod -l name=sealed-secrets-controller -n sealed-secrets-system --timeout=300s
        
        log_success "Sealed Secrets installed!"
    elif [ "$SECRET_MGMT" == "3" ]; then
        log_info "HashiCorp Vault setup not implemented yet"
    fi
    
    # Deploy demo applications based on configuration
    case $DEMO_APPS in
        1)
            deploy_guestbook "$cluster"
            ;;
        2)
            deploy_guestbook "$cluster"
            deploy_monitoring "$cluster"
            ;;
        3)
            deploy_guestbook "$cluster"
            deploy_monitoring "$cluster"
            deploy_additional_demos "$cluster"
            ;;
    esac
}

# Deploy guestbook application
deploy_guestbook() {
    local cluster=${1:-dev}
    
    log_info "Deploying guestbook application to cluster: $cluster"
    
    # Create guestbook namespace
    kubectl create namespace guestbook --dry-run=client -o yaml | kubectl apply -f -
    
    # Create ArgoCD application for guestbook
    cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: ${GIT_REPO:-https://github.com/argoproj/argocd-example-apps.git}
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: guestbook
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
    
    log_success "Guestbook application deployed via ArgoCD"
}

# Deploy monitoring stack (basic)
deploy_monitoring() {
    local cluster=${1:-dev}
    
    log_info "Deploying monitoring stack to cluster: $cluster"
    
    # This is a placeholder - would install Prometheus/Grafana
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    log_info "Monitoring deployment (placeholder) - full implementation coming soon"
}

# Deploy additional demo applications
deploy_additional_demos() {
    local cluster=${1:-dev}
    
    log_info "Deploying additional demo applications to cluster: $cluster"
    
    # This is a placeholder for more complex demos
    log_info "Additional demos (placeholder) - full implementation coming soon"
}

# Display status and next steps
show_status() {
    echo ""
    log_success "╔═══════════════════════════════════════════════════════════╗"
    log_success "║  Bootstrap Complete!                                      ║"
    log_success "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    
    # Determine clusters
    if [[ "$MULTI_ENV" =~ ^[Yy]$ ]]; then
        CLUSTERS=("dev" "staging" "prod")
    else
        CLUSTERS=("dev")
    fi
    
    for cluster in "${CLUSTERS[@]}"; do
        if [ -f "${SCRIPT_DIR}/bootstrap/${cluster}.kubeconfig" ]; then
            log_info "Cluster: $cluster"
            echo "  Export kubeconfig: export KUBECONFIG=\"${SCRIPT_DIR}/bootstrap/${cluster}.kubeconfig\""
            echo "  ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
            echo "  Get ArgoCD password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
            echo ""
        fi
    done
    
    log_info "Next steps:"
    echo "  1. Access ArgoCD UI (see commands above)"
    echo "  2. Check application status: kubectl get applications -n argocd"
    echo "  3. View pods: kubectl get pods -A"
    echo "  4. Access guestbook: kubectl port-forward -n guestbook svc/guestbook-ui 8081:80"
    echo ""
    log_info "Configuration saved in: $CONFIG_FILE"
    echo ""
    log_info "For help: $0 --help"
}

# Main bootstrap flow
main() {
    print_banner
    echo ""
    
    # Check if we have a saved configuration
    if load_config && [ "$1" != "configure" ]; then
        log_info "Found existing configuration"
        read -p "Use existing configuration? [Y/n]: " use_existing
        use_existing=${use_existing:-Y}
        
        if [[ ! "$use_existing" =~ ^[Yy]$ ]]; then
            configure_platform
        fi
    else
        configure_platform
    fi
    
    check_prerequisites
    
    # Bootstrap infrastructure
    if [ "$DEPLOY_MODE" == "1" ]; then
        bootstrap_local
        
        # Determine clusters to set up
        if [[ "$MULTI_ENV" =~ ^[Yy]$ ]]; then
            CLUSTERS=("dev" "staging" "prod")
        else
            CLUSTERS=("dev")
        fi
        
        # Install components on each cluster
        for cluster in "${CLUSTERS[@]}"; do
            if [ -f "${SCRIPT_DIR}/bootstrap/${cluster}.kubeconfig" ]; then
                install_components "$cluster"
            fi
        done
    else
        log_error "Cloud deployments not yet implemented. Please use local mode (option 1)."
        exit 1
    fi
    
    show_status
}

# Handle arguments
case "${1:-}" in
    configure)
        print_banner
        configure_platform
        ;;
    status)
        if load_config; then
            show_status
        else
            log_error "No configuration found. Run bootstrap first."
            exit 1
        fi
        ;;
    clean)
        log_warn "This will destroy all local KIND clusters!"
        read -p "Are you sure? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            kind delete clusters --all 2>/dev/null || true
            rm -f "${SCRIPT_DIR}/bootstrap/*.kubeconfig"
            rm -f "$CONFIG_FILE"
            log_success "Cleanup complete"
        fi
        ;;
    help|--help|-h)
        echo "GitOps Multi-Cluster Platform Bootstrap"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  (none)      - Run interactive bootstrap"
        echo "  configure   - Reconfigure platform settings"
        echo "  status      - Show current status and access information"
        echo "  clean       - Destroy all local resources"
        echo "  help        - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0              # Interactive bootstrap"
        echo "  $0 configure    # Reconfigure settings"
        echo "  $0 status       # Show access information"
        echo "  $0 clean        # Clean up everything"
        ;;
    *)
        main "$@"
        ;;
esac