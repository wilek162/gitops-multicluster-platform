.PHONY: help demo bootstrap sync port-forward clean test

help:
	@echo "GitOps Multi-Cluster Platform - Available targets:"
	@echo ""
	@echo "  demo          - Complete local demo setup (bootstrap + sync)"
	@echo "  bootstrap     - Create kind cluster and install ArgoCD"
	@echo "  sync          - Deploy applications via ArgoCD"
	@echo "  port-forward  - Forward ArgoCD UI to localhost:8080"
	@echo "  password      - Get ArgoCD admin password"
	@echo "  clean         - Delete kind cluster"
	@echo "  test          - Run smoke tests"
	@echo ""

demo: bootstrap sync port-forward password

bootstrap:
	@echo "🚀 Bootstrapping local cluster..."
	bash ./bootstrap/scripts/bootstrap-kind-argocd.sh demo
	@echo ""
	@echo "✅ Bootstrap complete! Run 'make sync' to deploy apps"

sync:
	@echo "🔄 Deploying applications via ArgoCD..."
	@export KUBECONFIG="$$(pwd)/bootstrap/demo.kubeconfig" && \
	kubectl apply -f clusters/dev/argocd-app.yaml -n argocd
	@echo ""
	@echo "✅ Applications deployed! Check ArgoCD UI"

port-forward:
	@echo "🌐 Forwarding ArgoCD UI to https://localhost:8080"
	@export KUBECONFIG="$$(pwd)/bootstrap/demo.kubeconfig" && \
	kubectl port-forward svc/argocd-server -n argocd 8080:443

password:
	@echo "🔐 ArgoCD Admin Password:"
	@export KUBECONFIG="$$(pwd)/bootstrap/demo.kubeconfig" && \
	kubectl -n argocd get secret argocd-initial-admin-secret \
		-o jsonpath="{.data.password}" | base64 -d && echo

clean:
	@echo "🗑️  Deleting kind cluster..."
	kind delete cluster --name demo
	rm -f bootstrap/demo.kubeconfig
	@echo "✅ Cleanup complete"

test:
	@echo "🧪 Running smoke tests..."
	@export KUBECONFIG="$$(pwd)/bootstrap/demo.kubeconfig" && \
	kubectl get pods -n guestbook && \
	kubectl wait --for=condition=Ready pods -l app=guestbook -n guestbook --timeout=120s
	@echo "✅ Tests passed!"
