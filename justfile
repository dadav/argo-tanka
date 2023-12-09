# vim: set ft=make :

# check requirements
check:
	@command -v k3d &>/dev/null || echo "k3d not found."
	@command -v kubectl &>/dev/null || echo "kubectl not found."
	@command -v tk &>/dev/null || echo "tanka (tk) not found."

# start the cluster
start: check
	@k3d clister list foo || k3d cluster create foo

install: start
	@tk apply environments/default

# remove the cluster
destroy: check
	@k3d cluster list foo && k3d cluster delete foo
