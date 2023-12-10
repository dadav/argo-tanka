# vim: set ft=make :

# check requirements
check:
	@command -v k3d &>/dev/null || echo "k3d not found."
	@command -v kubectl &>/dev/null || echo "kubectl not found."
	@command -v tk &>/dev/null || echo "tanka (tk) not found."

# start the cluster
start: check
	@k3d cluster list foo &>/dev/null || k3d cluster create foo --api-port 9443

# install argocd with tanka support
install: start
	@tk env set tanka/environments/default --server=https://0.0.0.0:9443
	@tk apply tanka/environments/default

# remove the cluster
destroy: check
	@k3d cluster list foo &>/dev/null && k3d cluster delete foo
