# vim: set ft=make :

set export

CLUSTER_NAME := "foo"
API_PORT := "9443"

# check requirements
check:
	@command -v k3d &>/dev/null || echo "k3d not found."
	@command -v kubectl &>/dev/null || echo "kubectl not found."
	@command -v tk &>/dev/null || echo "tanka (tk) not found."

# start the cluster
start: check
	@k3d cluster list $CLUSTER_NAME &>/dev/null || k3d cluster create $CLUSTER_NAME --api-port $API_PORT

# install argocd with tanka support
install: start
	@tk env set tanka/environments/default --server=https://0.0.0.0:$API_PORT
	@tk apply tanka/environments/default

# remove the cluster
destroy: check
	@k3d cluster list $CLUSTER_NAME &>/dev/null && k3d cluster delete $CLUSTER_NAME

# reset the whole environment
reset: check destroy start install

# enable portforwarding
port-forward: check
	@kubectl -n argocd port-forward "$(kubectl -n argocd wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server --timeout=30s -o jsonpath='{.metadata.name}')" 8080:8080 &>/dev/null &
